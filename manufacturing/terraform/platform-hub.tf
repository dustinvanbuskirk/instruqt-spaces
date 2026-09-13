# platform-hub.tf
#
# Connects Octopus's Platform Hub to the Git repo it reads process/project
# templates from — instruqt-sample-applications, mirrored into Gitea at
# image-build time (the same shared repo every advanced track in this org
# already reads its "golden" templates from). No octopusdeploy Terraform
# provider resource covers Platform Hub's version-control connection (a
# newer, proprietary API the provider doesn't model), so this is a
# null_resource + direct API call, matching this project's established
# pattern for every other provider gap (see gitea.tf's
# tag_and_build_services, environments.tf's set_environment_sort_order).
#
# A plain PUT is idempotent — it replaces whatever was configured before
# rather than erroring if something's already there, confirmed against
# this org's own verified Octopus/Platform Hub API findings — so this is
# safe to leave in place even though a challenge's own setup script
# (instruqt-advanced-training-gitops' 01-configure-golden-argo-template/
# setup-track-image) also configures the same connection: whichever runs
# last wins, and both write the identical values.
resource "null_resource" "connect_platform_hub" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL     = var.octopus_server_url
      OCTOPUS_API_KEY = var.octopus_api_key
      GITEA_PASSWORD  = var.gitea_password
    }
    command = <<-EOT
      set -euo pipefail

      # "gitea:3000" (not "localhost:3000"): this URL is read by the
      # Octopus *container* itself when it later clones/fetches from
      # Platform Hub's connected repo, not by Terraform — same
      # host-vs-in-cluster distinction as the rest of this configuration.
      BODY=$(jq -n --arg password "$${GITEA_PASSWORD}" '{
        Url: "http://gitea:3000/admin/instruqt-sample-applications.git",
        Credentials: {
          Type: "UsernamePassword",
          Username: "admin",
          Password: { HasValue: true, NewValue: $password }
        },
        DefaultBranch: "main",
        BasePath: ".octopus/platform-hub"
      }')

      HTTP=$(curl -s -o /tmp/platform-hub-versioncontrol-response.json -w "%%{http_code}" \
        --max-time 15 \
        -X PUT "$${OCTOPUS_URL}/api/platformhub/versioncontrol" \
        -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$${BODY}")

      if [ "$${HTTP}" -lt 200 ] || [ "$${HTTP}" -ge 300 ]; then
        echo "✗ Failed to connect Platform Hub to instruqt-sample-applications (HTTP $${HTTP})" >&2
        cat /tmp/platform-hub-versioncontrol-response.json >&2 2>/dev/null || true
        exit 1
      fi
      echo "✓ Platform Hub connected to http://gitea:3000/admin/instruqt-sample-applications.git (.octopus/platform-hub)"
    EOT
  }
}

# Publishes and shares every process template Platform Hub can see on the
# connected repo's working branch — not just the one golden-argo-helm-
# deployment template instruqt-advanced-training-gitops' own
# 01-configure-golden-argo-template/setup-track-image already handles.
# Any other process template added under .octopus/platform-hub/process-
# templates in instruqt-sample-applications becomes usable from this
# Terraform alone, with no matching change needed per-track.
#
# Publish and share calls are each idempotent in their own way: publishing
# the same slug+version twice returns 409 (treated as success below,
# matching the same handling already confirmed in that challenge script),
# and sharing just replaces whatever sharing was already configured.
resource "null_resource" "publish_platform_hub_process_templates" {
  depends_on = [null_resource.connect_platform_hub]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL     = var.octopus_server_url
      OCTOPUS_API_KEY = var.octopus_api_key
    }
    command = <<-EOT
      set -euo pipefail

      GIT_REF="refs/heads/main"
      VERSION="1.0.0"
      # Ref-scoped path (the Git working copy), not the unscoped one
      # (published/frozen versions) — see this org's own verified
      # Platform Hub API findings on the two base paths.
      HUB_REF="$${OCTOPUS_URL}/api/platformhub/refs%2Fheads%2Fmain"

      SLUGS=$(curl -sS --max-time 20 "$${HUB_REF}/processtemplates" \
        -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
        | jq -r '.ProcessTemplates[]?.Slug // empty')

      if [ -z "$${SLUGS}" ]; then
        echo "✗ No process templates found on $${GIT_REF} — is Platform Hub actually connected?" >&2
        exit 1
      fi

      echo "$${SLUGS}" | while IFS= read -r SLUG; do
        [ -z "$${SLUG}" ] && continue
        echo "--- Publishing process template '$${SLUG}' ---"

        PUBLISH_HTTP=$(curl -s -o /tmp/platform-hub-publish-"$${SLUG}".json -w "%%{http_code}" --max-time 60 \
          -X POST "$${HUB_REF}/processtemplates/$${SLUG}/versions" \
          -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
          -H "Content-Type: application/json" \
          -d "$(jq -n --arg slug "$${SLUG}" --arg ref "$${GIT_REF}" --arg version "$${VERSION}" \
            '{ProcessTemplateSlug: $slug, GitRef: $ref, Version: $version, IsPreRelease: false}')")

        if echo "$${PUBLISH_HTTP}" | grep -qE '^2'; then
          echo "  ✓ published $${SLUG} $${VERSION}"
        elif [ "$${PUBLISH_HTTP}" = "409" ]; then
          echo "  ✓ $${SLUG} $${VERSION} already published"
        else
          echo "  ✗ failed to publish $${SLUG} $${VERSION} (HTTP $${PUBLISH_HTTP})" >&2
          cat /tmp/platform-hub-publish-"$${SLUG}".json >&2 2>/dev/null || true
          exit 1
        fi

        # ShareToAllSpaces (not IndividuallySharedSpaceIds naming just
        # "Spaces-1"): this box only ever has the one Default space, so
        # the two are equivalent here, and this matches the exact call
        # shape already confirmed working in the challenge script above.
        SHARE_HTTP=$(curl -s -o /tmp/platform-hub-share-"$${SLUG}".json -w "%%{http_code}" --max-time 60 \
          -X POST "$${HUB_REF}/processtemplates/$${SLUG}/share" \
          -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
          -H "Content-Type: application/json" \
          -d "$(jq -n --arg slug "$${SLUG}" --arg ref "$${GIT_REF}" \
            '{ProcessTemplateSlug: $slug, GitRef: $ref, ShareToAllSpaces: true, IndividuallySharedSpaceIds: []}')")

        if echo "$${SHARE_HTTP}" | grep -qE '^2'; then
          echo "  ✓ shared $${SLUG} to the default space"
        else
          echo "  ✗ failed to share $${SLUG} (HTTP $${SHARE_HTTP})" >&2
          cat /tmp/platform-hub-share-"$${SLUG}".json >&2 2>/dev/null || true
          exit 1
        fi
      done
    EOT
  }
}
