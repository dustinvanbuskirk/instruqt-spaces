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
# All four of this configuration's own environment names are cleared here
# too (SQA, UAT, "Lead Site Production", "Production"), not just the one
# pre-baked collision — because on an Instruqt track sandbox,
# track_scripts/setup-track-image does `rm -rf` + a fresh `git clone` of
# this whole repo (Terraform state included) on *every* run, while the
# same underlying Octopus instance can persist across several such runs
# (confirmed directly: a run that got partway through creating these
# environments before failing on a later resource left them behind, and
# the next run's blank state tried to create them again — "An environment
# with this name already exists in this space"). Terraform's own state
# can't be trusted to reflect what already exists on the target instance
# in that situation, so this deletes any environment with one of these
# names unconditionally before the resources below try to create them,
# regardless of whether the name came from the original image bake or
# from this configuration's own previous, later-interrupted run.
#
# null_resource's own provisioner only runs once, at the resource's own
# creation — never again on a later `terraform apply` against the same
# state/backend, only if applied against a genuinely fresh one (empty
# state, e.g. a new box or a fresh clone). Combined with environments.tf's
# depends_on, that guarantees this script always runs *before* any of our
# own environment resources are created, so it's always safe to delete
# unconditionally here — there's no risk of racing/fighting with a
# same-apply resource, only ever clearing what a previous run already
# left behind (or the original bake).
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

      # All four of this configuration's own environment names — see the
      # top-of-file comment for why this can't be narrowed to just the
      # one pre-baked "Production" collision.
      for NAME in SQA UAT "Lead Site Production" Production; do
        # -G --data-urlencode (not a literal "?partialName=$NAME&..." query
        # string): "Lead Site Production" has spaces, and only Production/
        # SQA/UAT happened to not need encoding, which is exactly the kind
        # of gap that goes unnoticed until the one name with a space in it
        # silently doesn't get found.
        ENV_IDS=$(curl -s -G -H "X-Octopus-ApiKey: $${API_KEY}" \
            --data-urlencode "partialName=$${NAME}" \
            --data-urlencode "take=100" \
            "$${OCTOPUS_URL}/api/$${SPACE_ID}/environments" \
          | jq -r --arg n "$${NAME}" '.Items[] | select(.Name == $n) | .Id')

        if [ -z "$${ENV_IDS}" ]; then
          echo "No pre-existing '$${NAME}' environment to clear — skipping"
          continue
        fi

        # Looped rather than assumed-single: a name can match more than
        # one environment here (e.g. two earlier runs each got partway
        # through creating one before failing later), and only clearing
        # the first would leave the create step colliding again.
        for ENV_ID in $${ENV_IDS}; do
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
              PUT_HTTP=$(echo "$${LC_JSON}" \
                | jq --arg id "$${ENV_ID}" '
                    .Phases = [.Phases[] | .AutomaticDeploymentTargets -= [$id] | .OptionalDeploymentTargets -= [$id]]
                    | del(.Links)' \
                | curl -s -o /tmp/lifecycle-put-response.json -w "%%{http_code}" -X PUT \
                    -H "X-Octopus-ApiKey: $${API_KEY}" -H "Content-Type: application/json" \
                    -d @- "$${OCTOPUS_URL}/api/$${SPACE_ID}/lifecycles/$${LC}")
              if [ "$${PUT_HTTP}" -lt 200 ] || [ "$${PUT_HTTP}" -ge 300 ]; then
                echo "  ✗ Failed to clear reference from lifecycle $${LC} (HTTP $${PUT_HTTP}): $(cat /tmp/lifecycle-put-response.json)" >&2
                exit 1
              fi
              echo "  Cleared reference from lifecycle $${LC}"
            fi
          done

          # Never discard this: curl only fails (non-zero exit) on a
          # network-level problem, not an HTTP error status — a 400/409
          # here (the environment is still referenced by something this
          # script doesn't yet know to clear, e.g. a tenant's project
          # scoping from an earlier partial apply) would otherwise be
          # swallowed by `>/dev/null`, print "Deleted" anyway, and leave
          # the real conflict to resurface as a confusing "already
          # exists" much later when the create step runs.
          DELETE_HTTP=$(curl -s -o /tmp/env-delete-response.json -w "%%{http_code}" \
            -X DELETE -H "X-Octopus-ApiKey: $${API_KEY}" \
            "$${OCTOPUS_URL}/api/$${SPACE_ID}/environments/$${ENV_ID}")
          if [ "$${DELETE_HTTP}" -lt 200 ] || [ "$${DELETE_HTTP}" -ge 300 ]; then
            echo "  ✗ Failed to delete environment $${ENV_ID} (HTTP $${DELETE_HTTP}): $(cat /tmp/env-delete-response.json)" >&2
            exit 1
          fi
          echo "  Deleted environment $${ENV_ID}"
        done
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
