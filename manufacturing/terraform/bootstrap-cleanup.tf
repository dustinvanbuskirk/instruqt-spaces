# bootstrap-cleanup.tf
#
# This configuration targets Spaces-1 (the instance's Default space) rather
# than a dedicated space it creates itself — see variables.tf's
# octopus_space_id. That space already comes with a few resources baked in
# by instruqt-octopus-host-images' own configure-octopus.sh
# (octopusdeploy/configure-octopus.sh), every time the box is freshly
# provisioned: "Development"/"Test"/"Production" environments and a
# "Default Lifecycle" whose phases reference them.
#
# "Production" collides by name with octopusdeploy_environment.production
# below — confirmed directly against a freshly-provisioned box. Since this
# configuration gets applied against fresh boxes repeatedly (not just this
# one, once), that collision has to be handled here, not fixed by hand each
# time.
#
# null_resource's own provisioner only runs once, at the resource's own
# creation — never again on a later `terraform apply` against the same
# state/backend, only if applied against a genuinely fresh one (empty
# state, e.g. a new box). Combined with environments.tf's depends_on, that
# guarantees this script always runs *before* our own "Production"
# environment resource is created, so any environment literally named
# "Production" found here can only be the pre-existing baked-in one, never
# something Terraform itself is managing — safe to delete unconditionally,
# with no risk of this racing/fighting with our own resource on a later
# apply.
resource "null_resource" "clear_conflicting_bootstrap_environments" {
  triggers = {
    space_id = var.octopus_space_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL = var.octopus_server_url
      API_KEY     = var.octopus_api_key
      SPACE_ID    = var.octopus_space_id
    }
    # $${...} throughout (not ${...}): these must reach bash literally, to
    # be expanded from the `environment` block above at run time — not
    # interpolated by Terraform's own HCL heredoc at plan/apply-render time.
    command = <<-EOT
      set -euo pipefail

      # Extend this list if a future box bake adds more baked-in
      # environments that collide with names this configuration creates.
      for NAME in Production; do
        ENV_ID=$(curl -s -H "X-Octopus-ApiKey: $${API_KEY}" \
            "$${OCTOPUS_URL}/api/$${SPACE_ID}/environments?partialName=$${NAME}&take=100" \
          | jq -r --arg n "$${NAME}" '.Items[] | select(.Name == $n) | .Id')

        if [ -z "$${ENV_ID}" ]; then
          echo "No pre-existing '$${NAME}' environment to clear — skipping"
          continue
        fi
        echo "Found pre-existing '$${NAME}' environment ($${ENV_ID}) — clearing lifecycle references and deleting it"

        # An environment referenced by a lifecycle phase can't be deleted
        # until that reference is gone (confirmed directly: the API
        # rejects the delete otherwise) — strip it from every phase of
        # every lifecycle that references it first.
        for LC in $(curl -s -H "X-Octopus-ApiKey: $${API_KEY}" "$${OCTOPUS_URL}/api/$${SPACE_ID}/lifecycles?take=100" | jq -r '.Items[].Id'); do
          LC_JSON=$(curl -s -H "X-Octopus-ApiKey: $${API_KEY}" "$${OCTOPUS_URL}/api/$${SPACE_ID}/lifecycles/$${LC}")
          REFERENCED=$(echo "$${LC_JSON}" | jq --arg id "$${ENV_ID}" \
            '[.Phases[] | select((.AutomaticDeploymentTargets + .OptionalDeploymentTargets) | index($id))] | length')
          if [ "$${REFERENCED}" != "0" ]; then
            echo "$${LC_JSON}" \
              | jq --arg id "$${ENV_ID}" '
                  .Phases = [.Phases[] | .AutomaticDeploymentTargets -= [$id] | .OptionalDeploymentTargets -= [$id]]
                  | del(.Links)' \
              | curl -s -X PUT -H "X-Octopus-ApiKey: $${API_KEY}" -H "Content-Type: application/json" \
                  -d @- "$${OCTOPUS_URL}/api/$${SPACE_ID}/lifecycles/$${LC}" >/dev/null
            echo "  Cleared reference from lifecycle $${LC}"
          fi
        done

        curl -s -X DELETE -H "X-Octopus-ApiKey: $${API_KEY}" "$${OCTOPUS_URL}/api/$${SPACE_ID}/environments/$${ENV_ID}" >/dev/null
        echo "  Deleted environment $${ENV_ID}"
      done
    EOT
  }
}

# Spaces-1 also comes with a built-in "Default Project Group" that this
# configuration has no use for (it creates its own "IT Manufacturing"/
# "IT Engineering" groups instead) — removed for a clean space, same
# self-healing-on-a-fresh-box reasoning as the environment cleanup above.
# Only deletes it if it's actually empty (defensive: a real, populated
# Default Project Group on some other instance this config gets pointed at
# should NOT be silently deleted).
resource "null_resource" "clear_default_project_group" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL = var.octopus_server_url
      API_KEY     = var.octopus_api_key
      SPACE_ID    = var.octopus_space_id
    }
    command = <<-EOT
      set -euo pipefail

      GROUP_ID=$(curl -s -H "X-Octopus-ApiKey: $${API_KEY}" \
          "$${OCTOPUS_URL}/api/$${SPACE_ID}/projectgroups?partialName=Default%20Project%20Group&take=100" \
        | jq -r '.Items[] | select(.Name == "Default Project Group") | .Id')

      if [ -z "$${GROUP_ID}" ]; then
        echo "No 'Default Project Group' to clear — skipping"
        exit 0
      fi

      PROJECT_COUNT=$(curl -s -H "X-Octopus-ApiKey: $${API_KEY}" \
        "$${OCTOPUS_URL}/api/$${SPACE_ID}/projectgroups/$${GROUP_ID}/projects" | jq -r '.TotalResults')
      if [ "$${PROJECT_COUNT}" != "0" ]; then
        echo "'Default Project Group' ($${GROUP_ID}) has $${PROJECT_COUNT} project(s) — leaving it alone"
        exit 0
      fi

      curl -s -X DELETE -H "X-Octopus-ApiKey: $${API_KEY}" "$${OCTOPUS_URL}/api/$${SPACE_ID}/projectgroups/$${GROUP_ID}" >/dev/null
      echo "Deleted empty 'Default Project Group' ($${GROUP_ID})"
    EOT
  }
}
