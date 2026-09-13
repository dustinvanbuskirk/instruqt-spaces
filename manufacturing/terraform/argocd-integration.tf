# argocd-integration.tf
#
# Deliberately seeds a BROKEN state: the Argo CD Octopus Gateway is
# uninstalled on every apply, even though instruqt-octopus-host-images'
# configure-octopus.sh installs it once at image-build/provision time
# (Helm release "octopus-argo" in namespace
# "octopus-argo-cd-gateway", via chart
# octopusdeploy/octopus-argocd-gateway-chart — see that script's "ArgoCD
# gateway" section, lines ~368-429). This project now has a dedicated
# challenge (instruqt-advanced-training-gitops' new 01-... challenge) whose
# whole premise is installing that gateway by hand from the terminal and
# scoping it to this project's real environments (SQA, UAT, Lead Site
# Production, Production) instead of the image-build-time default
# (development/test/production, none of which exist in this project) — so
# the environment every learner boots into must actually have no gateway
# installed, rather than have it pre-solved by Terraform.
#
# Namespace deleted too (not just `helm uninstall`): a bare uninstall
# leaves the namespace (and anything Helm doesn't own inside it) behind,
# so a learner's fresh `helm upgrade --install --create-namespace` isn't
# quite starting from the same clean slate the image-build-time install
# started from. Both are best-effort — a from-scratch box that never had
# the gateway installed at all should hit neither, not fail this resource.
#
# The Octopus-side "Argo CD Instance" registration is deleted too — helm
# uninstalling the gateway only removes the cluster-side pod, not the
# Octopus-side record it registered on startup. Confirmed directly: after
# uninstalling the Helm release alone, Octopus's Infrastructure > Argo CD
# Instances page kept showing "octopus-argo" as still connected. The
# DELETE endpoint's exact shape isn't confirmed anywhere in Octopus's docs
# (same gap as the GET/PUT calls already used above and in check scripts),
# but mirrors the same /api/spaces/{spaceId}/argocdinstances/{id} path —
# best-effort, treating a 404 as already-gone.
resource "null_resource" "uninstall_argocd_gateway" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      OCTOPUS_URL     = var.octopus_server_url
      OCTOPUS_API_KEY = var.octopus_api_key
      SPACE_ID        = var.octopus_space_id
    }
    command = <<-EOT
      set -euo pipefail

      RELEASE="octopus-argo"
      NAMESPACE="octopus-argo-cd-gateway"

      if helm status "$${RELEASE}" -n "$${NAMESPACE}" >/dev/null 2>&1; then
        echo "Uninstalling Helm release '$${RELEASE}' from namespace '$${NAMESPACE}'..."
        helm uninstall "$${RELEASE}" -n "$${NAMESPACE}"
        echo "✓ Uninstalled '$${RELEASE}'"
      else
        echo "No existing '$${RELEASE}' release in '$${NAMESPACE}' — nothing to uninstall"
      fi

      if kubectl get namespace "$${NAMESPACE}" >/dev/null 2>&1; then
        echo "Deleting namespace '$${NAMESPACE}'..."
        kubectl delete namespace "$${NAMESPACE}" --ignore-not-found --wait=true --timeout=60s
        echo "✓ Deleted namespace '$${NAMESPACE}'"
      else
        echo "Namespace '$${NAMESPACE}' doesn't exist — nothing to delete"
      fi

      INSTANCE_IDS=$(curl -sf -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
        "$${OCTOPUS_URL}/api/spaces/$${SPACE_ID}/argocdinstances/summaries?partialName=" \
        | jq -r '.Items[]?.Id // empty')

      if [ -z "$${INSTANCE_IDS}" ]; then
        echo "No Argo CD Instance registered in Octopus — nothing to deregister"
      else
        for INSTANCE_ID in $${INSTANCE_IDS}; do
          HTTP=$(curl -s -o /tmp/argocd-instance-delete-response.json -w "%%{http_code}" -X DELETE \
            -H "X-Octopus-ApiKey: $${OCTOPUS_API_KEY}" \
            "$${OCTOPUS_URL}/api/spaces/$${SPACE_ID}/argocdinstances/$${INSTANCE_ID}")
          if echo "$${HTTP}" | grep -qE '^(2|404)'; then
            echo "✓ Deregistered Argo CD Instance $${INSTANCE_ID} from Octopus (HTTP $${HTTP})"
          else
            echo "✗ Failed to deregister Argo CD Instance $${INSTANCE_ID} (HTTP $${HTTP})" >&2
            cat /tmp/argocd-instance-delete-response.json >&2 2>/dev/null || true
            exit 1
          fi
        done
      fi
    EOT
  }
}
