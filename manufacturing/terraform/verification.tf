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
#
# One exception: photo-production-fab-16 is deliberately seeded broken
# (a bad image.registry override, fixed by the learner in the
# troubleshoot-photo-production track challenge) and is excluded from the
# "must be Healthy" requirement below — with a positive check that it's
# actually Degraded, not just skipped, so a track boot doesn't silently
# pass with that seeded failure missing.

resource "null_resource" "verify_service_builds" {
  # install_worker_tooling has no dependency of its own and normally has
  # no reason to run before or after this — added explicitly so a broken
  # worker (pwsh install failing, confirmed to happen live) fails fast,
  # before burning the 15-90 minutes this and verify_argocd_apps_healthy
  # can take, rather than surfacing only at the very end of the apply.
  depends_on = [null_resource.tag_and_build_services, null_resource.install_worker_tooling]

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

      # 90 attempts (15 minutes) per repo, not 40 (6.67 minutes): gitea-runner's
      # capacity is 1 (see instruqt-octopus-host-images' gitea/config.yaml,
      # a shared host-image setting this Terraform doesn't own), so only one
      # of photo/probe's builds can run at a time. Confirmed directly:
      # whichever gets picked up second sits "queued" for this box's own
      # observed single-build duration (~6-7 minutes) before it even starts,
      # which alone can exceed a 40-attempt budget before the build itself
      # has had any chance to complete.
      for repo in manufacturing-photo manufacturing-probe; do
        echo "--- Waiting for $${repo}'s v1.0.0 build-and-push run to complete ---"
        DONE=0
        PREV_STATE=""
        for i in $(seq 1 90); do
          RUN=$(curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" \
              "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/actions/runs?limit=1" \
            | jq -c '.workflow_runs[0] // empty')

          if [ -z "$${RUN}" ]; then
            if [ "no-run" != "$${PREV_STATE}" ] || [ $((i % 6)) -eq 0 ]; then
              echo "  ...no runs found yet for $${repo} (attempt $${i}/90)"
            fi
            PREV_STATE="no-run"
            sleep 10
            continue
          fi

          RUN_ID=$(echo "$${RUN}" | jq -r '.id // empty')
          STATUS=$(echo "$${RUN}" | jq -r '.status // ""')
          CONCLUSION=$(echo "$${RUN}" | jq -r '.conclusion // ""')
          # Logged only on a state change, plus a heartbeat every ~60s —
          # not on every single 10s poll. A build that takes several
          # minutes to reach a conclusion was otherwise printing dozens of
          # near-identical lines, which pushed the actually useful failure
          # detail further back in whatever buffer Instruqt's own log
          # capture retains, past what it keeps: confirmed directly, a
          # failure whose polling ran ~6 minutes showed nothing but the
          # tail end of a cleanup hook in the captured log, never the
          # step-detail dump below.
          CUR_STATE="$${STATUS}:$${CONCLUSION}"
          if [ "$${CUR_STATE}" != "$${PREV_STATE}" ] || [ $((i % 6)) -eq 0 ]; then
            echo "  $${repo} latest run (id=$${RUN_ID}): status=$${STATUS}, conclusion=$${CONCLUSION} (attempt $${i}/90)"
          fi
          PREV_STATE="$${CUR_STATE}"

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
                      # Persisted to a file rather than relied on to show up
                      # in full in the Instruqt track log: even printing the
                      # *entire* log inline (a prior version of this script
                      # tail-limited it — removed for exactly this reason),
                      # two separate failures still showed nothing past the
                      # tail-end cleanup/post-step output, confirming
                      # Instruqt's own log viewer caps what it displays or
                      # lets you copy, independent of what this script
                      # prints. The file is readable in full from the
                      # Terminal tab regardless of that cap. Secret values
                      # Gitea has already masked server-side (e.g. "***" in
                      # place of a matched secret) stay masked here too —
                      # nothing here can un-redact what Gitea itself redacted.
                      LOG_FILE="/tmp/gitea-build-failure-$${repo}-job-$${JOB_ID}.log"
                      if curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" \
                          "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/actions/jobs/$${JOB_ID}/logs" \
                          >"$${LOG_FILE}" 2>/dev/null; then
                        LINE_COUNT=$(wc -l <"$${LOG_FILE}" 2>/dev/null || echo "?")
                        echo "  full log for job '$${JOB_NAME}' ($${LINE_COUNT} lines) saved to: $${LOG_FILE}" >&2
                        echo "  (open it from the Terminal tab for the complete log — the excerpt below is only around the failing step)" >&2
                        # The tail end of the log is *always* the post-job
                        # cleanup hooks (they run via always(), regardless
                        # of where the real failure was) — confirmed
                        # directly: a tail-40 excerpt showed nothing but
                        # "Post Checkout code"/"Post Docker Buildx"
                        # succeeding, never the actual error, even once we
                        # knew exactly which step (by name, from the steps[]
                        # dump above) had failed. Locating that step's own
                        # "Run <name>" marker line and excerpting forward
                        # from there lands on the actual failure instead.
                        FAILED_STEP=$(echo "$${JOB}" | jq -r '[.steps[]? | select(.conclusion == "failure")] | first.name // empty')
                        START_LINE=""
                        if [ -n "$${FAILED_STEP}" ]; then
                          START_LINE=$(grep -n -F "Run $${FAILED_STEP}" "$${LOG_FILE}" | head -1 | cut -d: -f1)
                        fi
                        if [ -n "$${START_LINE}" ]; then
                          # Span the whole step, not an arbitrary fixed
                          # line count: a real `docker buildx build --push`
                          # step can log hundreds of lines (base image
                          # pulls, layer-by-layer output), and a fixed
                          # head -80 window cut off the actual error
                          # entirely — confirmed directly, the excerpt
                          # showed this step's own input evaluation, then
                          # jumped straight to its always()-triggered
                          # post-hook with nothing shown in between. The
                          # next "⭐ Run " marker after this step's own
                          # reliably marks where the next step (usually
                          # this same step's own post-hook) begins, so
                          # print up to — not including — that line; a
                          # generous 400-line cap is a last-resort safety
                          # net only, in case no next marker exists at all.
                          REL_END=$(tail -n "+$((START_LINE + 1))" "$${LOG_FILE}" | grep -n -F '⭐ Run ' | head -1 | cut -d: -f1)
                          if [ -n "$${REL_END}" ]; then
                            END_LINE=$((START_LINE + REL_END - 1))
                            if [ $((END_LINE - START_LINE)) -gt 400 ]; then
                              END_LINE=$((START_LINE + 400))
                            fi
                          else
                            END_LINE=$((START_LINE + 400))
                          fi
                          echo "  --- log from '$${FAILED_STEP}' (lines $${START_LINE}-$${END_LINE}) ---" >&2
                          sed -n "$${START_LINE},$${END_LINE}p" "$${LOG_FILE}" | sed 's/^/    /' >&2
                        else
                          echo "  (could not locate the failing step's marker in the log — showing the tail instead)" >&2
                          tail -40 "$${LOG_FILE}" | sed 's/^/    /' >&2
                        fi
                      else
                        echo "  (could not fetch log for job $${JOB_ID})" >&2
                      fi
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

      # Deletes every pod in a degraded/unhealthy app's own destination
      # namespace, forcing a clean restart regardless of the specific
      # underlying reason (ImagePullBackOff, CrashLoopBackOff, a stale
      # config, etc). Broader than only targeting ImagePullBackOff
      # specifically, which an earlier version of this script did on
      # every single poll — confirmed directly that the same set of
      # apps stayed Degraded, completely unchanged, for over 20 minutes
      # straight under that narrower approach, meaning whatever was
      # actually wrong with them wasn't an image pull problem at all.
      # Called at two fixed checkpoints (attempt 2, then attempt 20)
      # rather than every poll — enough to give a genuinely stuck app a
      # real kick without repeatedly restarting pods that just need a
      # little more time to settle on their own.
      # photo-production-fab-16 is deliberately, permanently broken (see
      # instruqt-spaces' seeded image.registry override and the
      # troubleshoot-photo-production track challenge that has the
      # learner fix it) — it must never be treated as "not yet ready" by
      # this resource, or this apply would wait the full 20 minutes and
      # then fail every single time, and the remediation kick below would
      # just repeatedly delete its pods for no benefit (they'd come right
      # back with the same ImagePullBackOff).
      EXPECTED_DEGRADED_APP="photo-production-fab-16"

      # Never touch the argocd namespace, unconditionally, regardless of
      # which app or why — it's Argo CD's own control-plane namespace
      # (server, repo-server, application-controller, etc.), never a
      # destination any of this project's own seeded workloads deploy
      # into. Confirmed directly: it-manufacturing-apps (the app-of-apps
      # itself, whose own destination.namespace is "argocd") went
      # Degraded once, and this remediation deleted every pod in
      # "argocd" trying to "fix" it — taking down Argo CD's own
      # server/controller pods. This guard makes that impossible
      # regardless of which app triggers it or why.
      is_argocd_namespace() {
        [ "$1" = "argocd" ]
      }

      remediate_degraded_apps() {
        local checkpoint="$1"
        echo "  ⚠ checkpoint (attempt $${checkpoint}): deleting pods for currently degraded/unhealthy apps"
        echo "$${APPS_JSON}" | jq -r --arg skip "$${EXPECTED_DEGRADED_APP}" \
            '.items[] | select(.metadata.name != $skip and (.status.health.status // "Unknown") != "Healthy") | .metadata.name' \
          | while read -r app; do
              [ -z "$${app}" ] && continue
              NS=$(kubectl -n argocd get application "$${app}" -o jsonpath='{.spec.destination.namespace}' 2>/dev/null || true)
              if [ -z "$${NS}" ]; then
                echo "    (could not resolve destination namespace for $${app} — skipping)"
                continue
              fi
              if is_argocd_namespace "$${NS}"; then
                echo "    (app '$${app}' destination namespace is 'argocd' — never deleting pods there, skipping)"
                continue
              fi
              echo "    ↻ deleting all pods in namespace '$${NS}' (app: $${app})"
              kubectl delete pods --all -n "$${NS}" --ignore-not-found >/dev/null 2>&1 || true
            done
      }

      echo "--- Waiting for all Argo CD Applications to be Synced and Healthy ---"
      PREV_NOT_READY=""
      # 80 attempts (20 minutes), not 40 (10 minutes): confirmed directly
      # that most apps reach Healthy well within the old budget, but a
      # handful stayed Degraded/Progressing the entire 10 minutes — the
      # ImagePullBackOff pattern above, which the kick below now also
      # addresses directly rather than just giving it more time to
      # resolve on its own.
      for i in $(seq 1 80); do
        APPS_JSON=$(kubectl -n argocd get applications.argoproj.io -o json)
        TOTAL=$(echo "$${APPS_JSON}" | jq '.items | length')

        if [ "$${TOTAL}" -eq 0 ]; then
          if [ "no-apps" != "$${PREV_NOT_READY}" ] || [ $((i % 4)) -eq 0 ]; then
            echo "  ...no Argo CD Applications found yet (attempt $${i}/80)"
          fi
          PREV_NOT_READY="no-apps"
          sleep 15
          continue
        fi

        NOT_READY=$(echo "$${APPS_JSON}" | jq -r --arg skip "$${EXPECTED_DEGRADED_APP}" '
          .items[]
          | select(.metadata.name != $skip)
          | select((.status.sync.status // "Unknown") != "Synced" or (.status.health.status // "Unknown") != "Healthy")
          | "\(.metadata.name): sync=\(.status.sync.status // "Unknown") health=\(.status.health.status // "Unknown")"
        ')

        if [ -z "$${NOT_READY}" ]; then
          echo "✓ All $${TOTAL} Argo CD Application(s) are Synced and Healthy, except the deliberately-broken $${EXPECTED_DEGRADED_APP}"

          # Positive confirmation, not just an exclusion: if this app has
          # somehow become Healthy (the seeded values.yaml override got
          # reverted, or never took effect), the troubleshoot-photo-production
          # challenge would have nothing broken to find — fail loudly
          # rather than silently pass a track that's no longer set up
          # correctly for that challenge.
          DEGRADED_APP_HEALTH=$(echo "$${APPS_JSON}" | jq -r --arg app "$${EXPECTED_DEGRADED_APP}" \
            '.items[] | select(.metadata.name == $app) | .status.health.status // "Unknown"')

          if [ -z "$${DEGRADED_APP_HEALTH}" ]; then
            echo "✗ $${EXPECTED_DEGRADED_APP} not found among Argo CD Applications at all" >&2
            exit 1
          fi

          if [ "$${DEGRADED_APP_HEALTH}" = "Healthy" ]; then
            echo "✗ $${EXPECTED_DEGRADED_APP} is Healthy, but it's expected to be Degraded (its seeded broken image.registry override must be missing or reverted)" >&2
            exit 1
          fi

          echo "✓ $${EXPECTED_DEGRADED_APP} is $${DEGRADED_APP_HEALTH}, as expected"
          exit 0
        fi

        # Logged only when the set of not-ready apps changes, plus a
        # heartbeat every ~60s — same reasoning as verify_service_builds
        # above: a long wait here was printing every app's status on
        # every single 15s poll, which is exactly the kind of volume that
        # pushed useful detail out of Instruqt's own captured log buffer
        # in a previous failure.
        if [ "$${NOT_READY}" != "$${PREV_NOT_READY}" ] || [ $((i % 4)) -eq 0 ]; then
          echo "  ...waiting on $${TOTAL} Argo CD Application(s), not yet ready (attempt $${i}/80):"
          echo "$${NOT_READY}" | sed 's/^/    /'
        fi
        PREV_NOT_READY="$${NOT_READY}"

        if [ "$${i}" -eq 2 ] || [ "$${i}" -eq 20 ]; then
          remediate_degraded_apps "$${i}"
        fi

        sleep 15
      done

      echo "✗ Timed out waiting for all Argo CD Applications to become Synced and Healthy:" >&2
      kubectl -n argocd get applications.argoproj.io -o json \
        | jq -r '.items[] | "\(.metadata.name): sync=\(.status.sync.status // "Unknown") health=\(.status.health.status // "Unknown")"' >&2
      exit 1
    EOT
  }
}
