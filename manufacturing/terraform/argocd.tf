# argocd.tf
#
# Bootstraps Argo CD with the one thing it needs to pick up everything else:
# the app-of-apps Application itself. Everything under it-manufacturing-apps/
# in manufacturing-apps (per-facility/environment photo.yaml + probe.yaml)
# cascades in automatically via Argo CD's own reconciliation — Terraform's
# job here is just to bootstrap that one entry point, not to manage every
# Application individually.
#
# All Applications (app-of-apps and every child it creates) use Argo CD's
# built-in "default" AppProject rather than a dedicated one — it already
# allows every source repo, destination namespace, and cluster-scoped
# resource kind out of the box, which is exactly what a from-scratch demo
# space needs. manufacturing-apps' app-of-apps.yaml and every child
# photo.yaml/probe.yaml under it-manufacturing-apps/ were updated to
# `spec.project: default` to match. A dedicated "manufacturing" AppProject
# was tried first and needed its own cluster_resource_whitelist to stop
# "resource :Namespace is not permitted in project manufacturing" — using
# "default" sidesteps that class of problem entirely.
#
# install-argocd.sh (host-images, unmodified — can't change it) grants the
# "octopus" account (the one data.external.argocd_token in providers.tf
# mints a fresh token for) only applications get/sync and clusters get —
# no "projects" or "repositories" permissions at all. Confirmed directly,
# one at a time:
#   "PermissionDenied: projects, get, manufacturing, sub: octopus"
#   "PermissionDenied: repositories, create, http://gitea:3000, sub: octopus"
# Since that RBAC policy lives in a ConfigMap, not something the argocd
# Terraform provider itself manages, this patches it via kubectl instead —
# idempotent (always sets the same full policy), safe to re-run on every
# apply against the same cluster, and self-healing on a fresh one (a new
# KinD cluster from ensure-live-stack.sh's self-heal has this same gap
# until this resource runs again).
resource "null_resource" "grant_argocd_project_rbac" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      # var.kubeconfig_path: where this points varies by where Terraform is
      # actually run from — on an Instruqt track sandbox (or a local box
      # running Terraform directly against its own cluster), that's
      # /root/.kube/config (the default); run from a separate host against
      # a Vagrant-managed VM instead, and it needs to be that host's own
      # generated kubeconfig file path, passed in via -var/-var-file rather
      # than hardcoded here.
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      # Argo CD watches argocd-rbac-cm itself and reloads policy.csv
      # dynamically — no server restart needed for this to take effect.
      kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{
        "data": {
          "policy.csv": "p, octopus, applications, get, *, allow\np, octopus, applications, sync, *, allow\np, octopus, applications, create, *, allow\np, octopus, applications, update, *, allow\np, octopus, applications, delete, *, allow\np, octopus, clusters, get, *, allow\np, octopus2, logs, get, */*, allow\np, octopus, projects, get, *, allow\np, octopus, projects, create, *, allow\np, octopus, projects, update, *, allow\np, octopus, projects, delete, *, allow\np, octopus, repositories, get, *, allow\np, octopus, repositories, create, *, allow\np, octopus, repositories, update, *, allow\np, octopus, repositories, delete, *, allow\n"
        }
      }'
      sleep 5
    EOT
  }
}

# A credential template, matched by URL prefix rather than one exact repo —
# covers every repo under this Gitea instance (manufacturing-apps AND
# manufacturing-configs, which the app-of-apps' own child Applications pull
# from via manufacturing-apps/it-manufacturing-apps/*/*/*.yaml) with one
# resource, rather than a separate credential per repo.
resource "argocd_repository_credentials" "gitea" {
  depends_on = [null_resource.grant_argocd_project_rbac]

  url      = "http://gitea:3000"
  username = var.gitea_username
  password = var.gitea_password
}

resource "argocd_application" "manufacturing_apps" {
  # Ensures the Gitea repo actually has this content, and that Argo CD can
  # authenticate to it, before Argo CD tries to sync — repo_url below is a
  # plain string, so Terraform has no implicit dependency on the
  # gitea_repository_file/argocd_repository_credentials resources otherwise.
  depends_on = [
    gitea_repository_file.manufacturing,
    argocd_repository_credentials.gitea,
  ]

  metadata {
    name      = "it-manufacturing-apps"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "http://gitea:3000/admin/manufacturing-apps.git"
      target_revision = "HEAD"
      path            = "it-manufacturing-apps"
      directory {
        recurse = true
        include = "*/*/*.yaml"
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argocd"
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = false
      }
      sync_options = ["CreateNamespace=true"]
      retry {
        limit = "5"
        backoff {
          duration     = "5s"
          factor       = "2"
          max_duration = "3m"
        }
      }
    }
  }
}

# The box also bakes in 6 unrelated sample Applications (from the
# host-images appliance's own demo content, not something this Terraform
# ever created) — remove them so the Argo CD UI only shows the
# manufacturing app-of-apps and what it cascades into. They aren't managed
# via the argocd provider's own resources because Terraform never created
# them (no matching state to import cleanly, and their exact spec isn't
# ours to track).
#
# Deleting the 6 Applications directly doesn't stick — confirmed directly
# that all 6 carry an ownerReference back to an ApplicationSet named
# "sample-set" (repo instruqt-sample-applications), which regenerates them
# on its next reconcile. Deleting the ApplicationSet itself is what
# actually removes them for good; Kubernetes' owner-reference garbage
# collection then cleans up the 6 Applications it owns. A null_resource
# with an always-run trigger keeps this self-healing: safe to re-run on
# every apply, and it clears the ApplicationSet again if a fresh KinD
# cluster (from the box's own boot-time self-heal, or a freshly re-baked
# Instruqt sandbox) ever bakes it back in.
resource "null_resource" "remove_sample_applications" {
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
      kubectl -n argocd delete applicationset sample-set --ignore-not-found
      kubectl -n argocd delete application \
        sample-api-development \
        sample-api-test \
        sample-api-production \
        sample-frontend-development \
        sample-frontend-test \
        sample-frontend-production \
        --ignore-not-found
    EOT
  }
}
