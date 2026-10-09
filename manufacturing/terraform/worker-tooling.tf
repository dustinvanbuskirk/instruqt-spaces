# worker-tooling.tf
#
# Installs pwsh (and a few common CLIs) on the "octopus-worker" Tentacle
# container on every apply. See git history for why this exists alongside
# instruqt-octopus-host-images' configure-octopus.sh.
#
# Why release binaries instead of apt: the Tentacle image is Debian 11
# (bullseye), which is past end of LTS. Its packages are leaving
# deb.debian.org, and bullseye's apt-get update only *warns* on failed
# fetches and then reuses stale cached indexes, so installs 404 at fetch
# time (wget, unzip). That's deterministic and retries can't fix it. pwsh,
# kubectl, helm and jq are therefore pulled as pinned, distro-agnostic
# release artifacts. Only git still needs apt, and it's best-effort: if
# deb.debian.org fails, apt is repointed at archive.debian.org, and if that
# fails too, the install carries on without git rather than taking pwsh
# down with it.
#
# Retries remain for genuinely transient network failures against
# github.com / dl.k8s.io / get.helm.sh.
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

      install_tooling() {
        docker exec -i octopus-worker bash -s <<'INNER'
      set -euo pipefail
      PWSH_VERSION=7.4.6
      KUBECTL_VERSION=v1.31.4
      HELM_VERSION=v3.16.3
      JQ_VERSION=1.7.1

      fetch() {
        if command -v curl >/dev/null 2>&1; then
          curl -fsSL --retry 3 "$1" -o "$2"
        elif command -v wget >/dev/null 2>&1; then
          wget -q "$1" -O "$2"
        else
          echo "no curl or wget available in container" >&2
          return 1
        fi
      }

      # Returns 0 only if apt indexes are fresh and usable.
      apt_ready() {
        rm -rf /var/lib/apt/lists/*
        apt-get update >/tmp/apt-update.log 2>&1 || true
        if ! grep -qE "^(E|W): " /tmp/apt-update.log; then
          return 0
        fi
        . /etc/os-release
        echo "apt-get update failed on $VERSION_CODENAME; switching to archive.debian.org" >&2
        for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
          [ -f "$f" ] || continue
          sed -i \
            -e "s|deb.debian.org/debian-security|archive.debian.org/debian-security|g" \
            -e "s|security.debian.org/debian-security|archive.debian.org/debian-security|g" \
            -e "s|deb.debian.org/debian|archive.debian.org/debian|g" \
            -e "/-updates/s/^deb /# deb /" \
            "$f"
        done
        echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/99archive
        rm -rf /var/lib/apt/lists/*
        apt-get update >/tmp/apt-update.log 2>&1 || true
        if grep -qE "^E: " /tmp/apt-update.log; then
          cat /tmp/apt-update.log >&2
          return 1
        fi
        return 0
      }

      mkdir -p /tmp/wt && cd /tmp/wt

      # Need a downloader; only fall back to apt if neither exists.
      if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        apt_ready
        apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null
      fi

      # pwsh (critical) — portable tarball, no distro repo involved
      fetch "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH_VERSION/powershell-$PWSH_VERSION-linux-x64.tar.gz" pwsh.tgz
      mkdir -p /opt/microsoft/powershell/7
      tar -xzf pwsh.tgz -C /opt/microsoft/powershell/7
      chmod +x /opt/microsoft/powershell/7/pwsh
      ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
      pwsh -NoLogo -NoProfile -Command "exit 0"

      if ! command -v kubectl >/dev/null 2>&1; then
        fetch "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" /usr/local/bin/kubectl
        chmod +x /usr/local/bin/kubectl
      fi

      if ! command -v helm >/dev/null 2>&1; then
        fetch "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz" helm.tgz
        tar -xzf helm.tgz
        install -m 0755 linux-amd64/helm /usr/local/bin/helm
      fi

      if ! command -v jq >/dev/null 2>&1; then
        fetch "https://github.com/jqlang/jq/releases/download/jq-$JQ_VERSION/jq-linux-amd64" /usr/local/bin/jq
        chmod +x /usr/local/bin/jq
      fi

      # git (nice-to-have) — apt, best-effort
      if ! command -v git >/dev/null 2>&1; then
        if apt_ready && apt-get install -y -qq --no-install-recommends git >/dev/null; then
          :
        else
          echo "⚠ git not installed (apt unavailable) — continuing without it" >&2
        fi
      fi

      cd / && rm -rf /tmp/wt
      INNER
      }

      echo "Installing pwsh, kubectl, helm, jq, git on octopus-worker..."
      SUCCESS=0
      for attempt in 1 2 3 4 5; do
        if install_tooling >/tmp/worker-tooling-install.log 2>&1; then
          SUCCESS=1
          break
        fi
        echo "  attempt $${attempt}/5 failed" >&2
        if [ "$${attempt}" -lt 5 ]; then
          echo "  retrying in 10s..." >&2
          sleep 10
        fi
      done

      if [ "$${SUCCESS}" -eq 1 ]; then
        grep "⚠" /tmp/worker-tooling-install.log >&2 || true
        echo "✓ Installed worker tooling on octopus-worker"
      else
        echo "✗ Failed to install worker tooling on octopus-worker after 5 attempts" >&2
        echo "--- last attempt's output ---" >&2
        cat /tmp/worker-tooling-install.log >&2 2>/dev/null || true
        exit 1
      fi
    EOT
  }
}
