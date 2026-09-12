# verification.tf
#
# A final end-to-end gate: confirm the two services this configuration
# tags and dispatches builds for (see null_resource.tag_and_build_services
# in gitea.tf) actually finished building successfully, and only then
# confirm every Argo CD Application it seeded is Synced and Healthy.
# Ordered deliberately — an Argo CD Application whose Helm values already
# pin image tag v1.0.0 (checked into manufacturing/configs' values.yaml
# files) can only become genuinely Healthy once that exact image has been
# built and pushed; checking health before the build finishes would just
# catch pods stuck failing to pull an image that doesn't exist yet.

resource "null_resource" "verify_service_builds" {
  depends_on = [null_resource.tag_and_build_services]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      GITEA_URL      = var.gitea_url
      GITEA_USERNAME = var.gitea_username
      GITEA_PASSWORD = var.gitea_password
    }
    command = <<-EOT
      set -euo pipefail

      for repo in manufacturing-photo manufacturing-probe; do
        echo "--- Waiting for $${repo}'s v1.0.0 build-and-push run to complete ---"
        DONE=0
        for i in $(seq 1 40); do
          RUN=$(curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" \
              "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/actions/runs?limit=1" \
            | jq -c '.workflow_runs[0] // empty')

          if [ -z "$${RUN}" ]; then
            echo "  ...no runs found yet for $${repo} (attempt $${i}/40)"
            sleep 10
            continue
          fi

          RUN_ID=$(echo "$${RUN}" | jq -r '.id // empty')
          STATUS=$(echo "$${RUN}" | jq -r '.status // ""')
          CONCLUSION=$(echo "$${RUN}" | jq -r '.conclusion // ""')
          echo "  $${repo} latest run (id=$${RUN_ID}): status=$${STATUS}, conclusion=$${CONCLUSION}"

          if [ "$${STATUS}" = "completed" ]; then
            if [ "$${CONCLUSION}" = "success" ]; then
              echo "✓ $${repo}: v1.0.0 build completed successfully"
              DONE=1
            else
              echo "✗ $${repo}: v1.0.0 build completed with conclusion '$${CONCLUSION}'" >&2
              # Best-effort: dump each job's failing step and a tail of its
              # log, so the track log shows *why* the build failed instead
              # of just that it did. This API shape (Gitea's Actions
              # endpoints mirror GitHub's) is not confirmed against a live
              # instance, so every call here is guarded — a wrong field
              # name or unexpected response must never mask the real
              # failure already reported above, only add to it.
              (
                set +e
                echo "--- $${repo} run $${RUN_ID}: job details ---" >&2
                JOBS=$(curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" \
                  "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/actions/runs/$${RUN_ID}/jobs" 2>/dev/null)
                if [ -z "$${JOBS}" ]; then
                  echo "  (could not fetch job list for run $${RUN_ID})" >&2
                else
                  echo "$${JOBS}" | jq -c '.jobs[]? // empty' 2>/dev/null | while IFS= read -r JOB; do
                    JOB_ID=$(echo "$${JOB}" | jq -r '.id // empty')
                    JOB_NAME=$(echo "$${JOB}" | jq -r '.name // "unknown"')
                    JOB_CONCLUSION=$(echo "$${JOB}" | jq -r '.conclusion // "unknown"')
                    echo "  job '$${JOB_NAME}' (id=$${JOB_ID}): conclusion=$${JOB_CONCLUSION}" >&2
                    echo "$${JOB}" | jq -r '.steps[]? | select(.conclusion != "success" and .conclusion != "") | "    ✗ step: \(.name) (\(.status)/\(.conclusion))"' >&2
                    if [ -n "$${JOB_ID}" ]; then
                      # Deliberately the *full* log, not a tail. Whatever
                      # actually failed could be anywhere in it (the tail
                      # end is often just later steps' cleanup/post-run
                      # output, as seen directly: a tail-80 dump showed
                      # nothing but "Post Checkout code" succeeding and
                      # container cleanup, cutting off before whatever
                      # step actually failed). Secret values Gitea has
                      # already masked server-side (e.g. "***" in place of
                      # a matched secret) stay masked here too — this
                      # can't un-redact anything Gitea itself redacted,
                      # it only stops *this script* from truncating
                      # further on top of that.
                      echo "  --- full log for job '$${JOB_NAME}' ---" >&2
                      curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" \
                        "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/actions/jobs/$${JOB_ID}/logs" 2>/dev/null \
                        | sed 's/^/    /' >&2 \
                        || echo "    (could not fetch log for job $${JOB_ID})" >&2
                    fi
                  done
                fi
              )
              exit 1
            fi
            break
          fi
          sleep 10
        done

        if [ "$${DONE}" -ne 1 ]; then
          echo "✗ Timed out waiting for $${repo}'s v1.0.0 build to complete" >&2
          exit 1
        fi
      done
    EOT
  }
}

resource "null_resource" "verify_argocd_apps_healthy" {
  depends_on = [
    null_resource.verify_service_builds,
    argocd_application.manufacturing_apps,
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail

      echo "--- Waiting for all Argo CD Applications to be Synced and Healthy ---"
      for i in $(seq 1 40); do
        APPS_JSON=$(kubectl -n argocd get applications.argoproj.io -o json)
        TOTAL=$(echo "$${APPS_JSON}" | jq '.items | length')

        if [ "$${TOTAL}" -eq 0 ]; then
          echo "  ...no Argo CD Applications found yet (attempt $${i}/40)"
          sleep 15
          continue
        fi

        NOT_READY=$(echo "$${APPS_JSON}" | jq -r '
          .items[]
          | select((.status.sync.status // "Unknown") != "Synced" or (.status.health.status // "Unknown") != "Healthy")
          | "\(.metadata.name): sync=\(.status.sync.status // "Unknown") health=\(.status.health.status // "Unknown")"
        ')

        if [ -z "$${NOT_READY}" ]; then
          echo "✓ All $${TOTAL} Argo CD Application(s) are Synced and Healthy"
          exit 0
        fi

        echo "  ...waiting on $${TOTAL} Argo CD Application(s), not yet ready (attempt $${i}/40):"
        echo "$${NOT_READY}" | sed 's/^/    /'
        sleep 15
      done

      echo "✗ Timed out waiting for all Argo CD Applications to become Synced and Healthy:" >&2
      kubectl -n argocd get applications.argoproj.io -o json \
        | jq -r '.items[] | "\(.metadata.name): sync=\(.status.sync.status // "Unknown") health=\(.status.health.status // "Unknown")"' >&2
      exit 1
    EOT
  }
}
