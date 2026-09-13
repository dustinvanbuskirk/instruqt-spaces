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
