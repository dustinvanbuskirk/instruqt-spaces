# worker-tooling.tf
#
# Installs pwsh (and a few common CLIs) on the "octopus-worker" Tentacle
# container every time this Terraform applies — not just at VM-image-build
# time. instruqt-octopus-host-images' configure-octopus.sh now does this
# too, but that only takes effect the next time the base VM image itself is
# rebuilt; any sandbox already booted from an older image (or one where the
# manual fix wasn't run) keeps failing every Octopus.Script step with
# "Unable to execute pwsh, please ensure that pwsh is installed and is in
# the PATH" — confirmed live, repeatedly, against this project's own
# deployments. Doing it here too means every `terraform apply` — which
# this project's own track_scripts/setup-track-image already runs on every
# sandbox provisioning — fixes it directly, independent of which VM image
# version is underneath.
#
# always_run (not a static trigger): a plain null_resource's provisioner
# only runs once, at creation, and never again against an existing state —
# confirmed directly in bootstrap-cleanup.tf's own comments. This needs to
# actually run and check on every apply (an already-fixed worker container
# might get replaced/recreated between applies), so it uses the same
# always-run trigger as this project's other self-healing resources
# (platform-hub.tf, argocd-integration.tf) — the pwsh presence check below
# keeps that cheap when there's nothing to do.
resource "null_resource" "install_worker_tooling" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      if ! docker ps --format '{{.Names}}' | grep -qx octopus-worker; then
        echo "✗ 'octopus-worker' container not running — skipping tooling install"
        exit 0
      fi

      if docker exec octopus-worker bash -c 'command -v pwsh' >/dev/null 2>&1; then
        echo "✓ pwsh already installed on octopus-worker — nothing to do"
        exit 0
      fi

      echo "Installing pwsh, kubectl, helm, git, jq on octopus-worker..."
      if docker exec octopus-worker bash -c '
        set -e
        apt-get update -qq
        apt-get install -y -qq wget curl apt-transport-https gnupg jq git unzip ca-certificates >/dev/null

        wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
        dpkg -i /tmp/packages-microsoft-prod.deb >/dev/null
        rm -f /tmp/packages-microsoft-prod.deb
        apt-get update -qq
        apt-get install -y -qq powershell >/dev/null

        if ! command -v kubectl >/dev/null 2>&1; then
          curl -sL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
          chmod +x /usr/local/bin/kubectl
        fi

        if ! command -v helm >/dev/null 2>&1; then
          curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null
        fi
      ' >/dev/null 2>&1; then
        echo "✓ Installed pwsh, kubectl, helm, git, jq on octopus-worker"
      else
        echo "✗ Failed to install worker tooling on octopus-worker" >&2
        exit 1
      fi
    EOT
  }
}
