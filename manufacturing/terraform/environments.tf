# Environments
#
# sort_order controls the display order in the Octopus UI (Infrastructure >
# Environments, and the lifecycle/deployment-process phase chips) — it is
# NOT inferred from the order these resource blocks appear in this file, or
# from lifecycle.tf's phase order.
#
# It's deliberately NOT set here as a resource attribute. Setting it at
# create time hit a real provider bug when all 4 environments were created
# in the same apply: Octopus's create endpoint assigns sort_order based on
# insertion order regardless of what's requested, and the provider's
# post-apply consistency check then fails outright ("Provider produced
# inconsistent result after apply ... sort_order: was 0, but now 3") since
# what came back didn't match what was configured — fatal enough to abort
# the whole apply. Setting it via a follow-up API PATCH (below) sidesteps
# that: by the time it runs, every environment already exists, so a
# by-name PATCH is unambiguous and idempotent — safe to re-run on every
# apply, same as the rest of this project's self-healing null_resources.
resource "octopusdeploy_environment" "sqa" {
  space_id                     = var.octopus_space_id
  name                         = "SQA"
  description                  = "Software Quality Assurance environment for testing"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

resource "octopusdeploy_environment" "uat" {
  space_id                     = var.octopus_space_id
  name                         = "UAT"
  description                  = "User Acceptance Testing / Beta environment"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

resource "octopusdeploy_environment" "lead_site_production" {
  space_id                     = var.octopus_space_id
  name                         = "Lead Site Production"
  description                  = "Pre-production validation at the primary lead site (Fab 11) only, between UAT and Production"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

resource "octopusdeploy_environment" "production" {
  # See bootstrap-cleanup.tf — this name collides with an environment the
  # box already bakes in, which must be cleared first.
  depends_on = [null_resource.clear_conflicting_bootstrap_environments]

  space_id                     = var.octopus_space_id
  name                         = "Production"
  description                  = "Production environment for live manufacturing operations"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

# See the top-of-file comment: sets display order by PATCHing each
# environment's SortOrder directly via the Octopus API, after all 4 exist.
resource "null_resource" "set_environment_sort_order" {
  depends_on = [
    octopusdeploy_environment.sqa,
    octopusdeploy_environment.uat,
    octopusdeploy_environment.lead_site_production,
    octopusdeploy_environment.production,
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL     = var.octopus_server_url
      OCTOPUS_API_KEY = var.octopus_api_key
      SPACE_ID        = var.octopus_space_id
      SQA_ID          = octopusdeploy_environment.sqa.id
      UAT_ID          = octopusdeploy_environment.uat.id
      LEAD_SITE_ID    = octopusdeploy_environment.lead_site_production.id
      PRODUCTION_ID   = octopusdeploy_environment.production.id
    }
    command = <<-EOT
      set -euo pipefail
      set_sort_order() {
        local env_id="$1" order="$2"
        curl -sf -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
          "$${OCTOPUS_URL}/api/$${SPACE_ID}/environments/$${env_id}" \
          | jq --argjson order "$${order}" '.SortOrder = $order' \
          | curl -sf -X PUT -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" -H "Content-Type: application/json" \
            "$${OCTOPUS_URL}/api/$${SPACE_ID}/environments/$${env_id}" -d @- >/dev/null
      }
      set_sort_order "$${SQA_ID}" 0
      set_sort_order "$${UAT_ID}" 1
      set_sort_order "$${LEAD_SITE_ID}" 2
      set_sort_order "$${PRODUCTION_ID}" 3
    EOT
  }
}

# The pre-baked Kubernetes deployment target ("kubernetes", installed via
# the Octopus Kubernetes Agent at image-build time — see
# instruqt-octopus-host-images' configure-octopus.sh) registers scoped to
# whatever environment(s) existed then. bootstrap-cleanup.tf strips the
# old pre-baked "Production" (which it deletes) off this same machine, so
# without this, the machine ends up scoped to none of this configuration's
# environments and nothing can deploy to it. Adds (not replaces) all four
# of this configuration's environments to whatever EnvironmentIds the
# machine already has, so anything else already depending on it keeps
# working.
resource "null_resource" "assign_kubernetes_target_environments" {
  depends_on = [
    octopusdeploy_environment.sqa,
    octopusdeploy_environment.uat,
    octopusdeploy_environment.lead_site_production,
    octopusdeploy_environment.production,
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL   = var.octopus_server_url
      API_KEY       = var.octopus_api_key
      SPACE_ID      = var.octopus_space_id
      SQA_ID        = octopusdeploy_environment.sqa.id
      UAT_ID        = octopusdeploy_environment.uat.id
      LEAD_SITE_ID  = octopusdeploy_environment.lead_site_production.id
      PRODUCTION_ID = octopusdeploy_environment.production.id
    }
    command = <<-EOT
      set -euo pipefail

      MACHINE_ID=$(curl -s -G -H "X-Octopus-ApiKey: $${API_KEY}" \
          --data-urlencode "partialName=kubernetes" \
          --data-urlencode "take=100" \
          "$${OCTOPUS_URL}/api/$${SPACE_ID}/machines" \
        | jq -r '.Items[] | select(.Name == "kubernetes") | .Id' | head -1)

      if [ -z "$${MACHINE_ID}" ]; then
        echo "No 'kubernetes' deployment target found — skipping environment assignment"
        exit 0
      fi

      MACHINE_JSON=$(curl -s -H "X-Octopus-ApiKey: $${API_KEY}" "$${OCTOPUS_URL}/api/$${SPACE_ID}/machines/$${MACHINE_ID}")

      PUT_HTTP=$(echo "$${MACHINE_JSON}" \
        | jq --arg sqa "$${SQA_ID}" --arg uat "$${UAT_ID}" --arg lead "$${LEAD_SITE_ID}" --arg prod "$${PRODUCTION_ID}" '
            .EnvironmentIds = ((.EnvironmentIds // []) + [$sqa, $uat, $lead, $prod] | unique)
            | del(.Links)' \
        | curl -s -o /tmp/machine-assign-response.json -w "%%{http_code}" -X PUT \
            -H "X-Octopus-ApiKey: $${API_KEY}" -H "Content-Type: application/json" \
            -d @- "$${OCTOPUS_URL}/api/$${SPACE_ID}/machines/$${MACHINE_ID}")

      if [ "$${PUT_HTTP}" -lt 200 ] || [ "$${PUT_HTTP}" -ge 300 ]; then
        echo "✗ Failed to assign environments to deployment target $${MACHINE_ID} (HTTP $${PUT_HTTP}): $(cat /tmp/machine-assign-response.json)" >&2
        exit 1
      fi
      echo "✓ Assigned SQA/UAT/Lead Site Production/Production to deployment target '$${MACHINE_ID}'"
    EOT
  }
}