# argocd-integration.tf
#
# Deliberately seeds a BROKEN state: the Argo CD Octopus Gateway is
# uninstalled on every apply, even though instruqt-octopus-host-images'
# configure-octopus.sh installs it once at image-build/provision time
# (Helm release "octopus-argo" in namespace
# "octo-argo-gateway-octopus-argo", via chart
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
resource "null_resource" "uninstall_argocd_gateway" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      RELEASE="octopus-argo"
      NAMESPACE="octo-argo-gateway-octopus-argo"

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
    EOT
  }
}
