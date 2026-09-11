# gitea.tf
#
# Seeds the 4 manufacturing-* repos (with repoURL references in
# manufacturing-apps rewritten to point at Gitea instead of GitHub — see
# that repo's own content) into this Gitea instance,
# owned by the existing "admin" user. Their source content lives right next
# to this Terraform, as sibling directories under manufacturing/ in this
# same instruqt-spaces repo — this whole repo is cloned as one piece onto
# an Instruqt track VM (see track_scripts/setup-track-image in the
# instruqt-advanced-training-gitops track repo), so there's no local-machine
# path to account for here.
#
# Each repo's entire current file tree is pushed via one gitea_repository_file
# resource per file — deliberately chosen over a local-exec git push so this
# stays within the gitea provider's own declarative resources (drift-detected
# by Terraform) rather than a shell escape hatch. The cost: each file's
# initial write is its own commit (a repo with 90 files gets ~90 commits),
# not one combined commit per repo.
locals {
  manufacturing_repos = {
    manufacturing-apps = {
      path        = "${path.module}/../apps"
      description = "Argo CD app-of-apps: per-facility/environment Application manifests for the manufacturing tenants"
    }
    manufacturing-configs = {
      path        = "${path.module}/../configs"
      description = "Per-region/facility/environment Helm values for the manufacturing tenants' photo and probe services"
    }
    manufacturing-photo = {
      path        = "${path.module}/../photo"
      description = "Photo service source"
    }
    manufacturing-probe = {
      path        = "${path.module}/../probe"
      description = "Probe service source"
    }
  }

  # Flattens {repo => {path, description}} + each repo's own file tree into
  # one map keyed by "<repo>/<file_path>", suitable for a single for_each.
  #
  # fileset(path, "**") includes dotfiles/dot-directories, so this Terraform
  # module's own directory (this module's for_each never sources itself,
  # but a sibling content directory that's ever had `terraform init`/`apply`
  # run inside it directly would get its own .terraform/,
  # .terraform.lock.hcl, terraform.tfstate*, and *.tfplan picked up too —
  # confirmed directly, once, when this happened: a provider binary under
  # .terraform/providers/** isn't valid UTF-8, so file() outright fails on
  # it rather than just seeding junk. Filtered out here rather than
  # relying on every content directory staying clean.
  manufacturing_repo_files = merge([
    for repo_name, repo in local.manufacturing_repos : {
      for file_path in fileset(repo.path, "**") :
      "${repo_name}/${file_path}" => {
        repo_name = repo_name
        file_path = file_path
        full_path = "${repo.path}/${file_path}"
      }
      if !can(regex("(^|/)\\.terraform(\\.lock\\.hcl)?($|/)|(^|/)terraform\\.tfstate|\\.tfplan$", file_path))
    }
  ]...)
}

resource "gitea_repository" "manufacturing" {
  for_each = local.manufacturing_repos

  username       = var.gitea_username
  name           = each.key
  description    = each.value.description
  private        = false
  auto_init      = true
  default_branch = "main"
}

resource "gitea_repository_file" "manufacturing" {
  for_each = local.manufacturing_repo_files

  username       = var.gitea_username
  name           = gitea_repository.manufacturing[each.value.repo_name].name
  branch         = "main"
  file_path      = each.value.file_path
  content        = file(each.value.full_path)
  commit_message = "Seed ${each.value.file_path}"
}

# Gitea Actions credentials for the 2 service repos' own .gitea/workflows/
# build-and-push.yaml, which pushes each service's image into this Gitea
# instance's own built-in container registry. CONTAINER_REGISTRY is
# host:port only (what `docker login` takes) — the workflow appends
# "/admin/<service>" itself to build the actual image path, since docker
# login rejects a path component. Not named "GITEA_..." — confirmed
# directly that Gitea rejects that prefix on both variable and secret
# names. Job containers reach "gitea:3000" directly: the runner's own
# config.yaml joins job containers to the "octopusdeploy_default" Docker
# network gitea itself is on (confirmed directly on the box).
locals {
  manufacturing_service_repos = ["manufacturing-photo", "manufacturing-probe"]
}

resource "gitea_repository_actions_variable" "registry" {
  for_each   = toset(local.manufacturing_service_repos)
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  variable_name    = "CONTAINER_REGISTRY"
  value            = "gitea:3000"
}

resource "gitea_repository_actions_secret" "registry_username" {
  for_each   = toset(local.manufacturing_service_repos)
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  secret_name      = "REGISTRY_USERNAME"
  secret_value     = var.gitea_username
}

resource "gitea_repository_actions_secret" "registry_password" {
  for_each   = toset(local.manufacturing_service_repos)
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  secret_name      = "REGISTRY_PASSWORD"
  secret_value     = var.gitea_password
}

# Octopus credentials for the same 2 workflows' "Push Build Information" /
# "Create Release" steps. OCTOPUS_SERVER_URL is the in-network address
# ("octopus:8080", the container name on the shared "octopusdeploy_default"
# network) — not var.octopus_server_url, which is "localhost:8080" and only
# reachable from the host Terraform itself runs on, not from a job
# container. OCTOPUS_PROJECT differs per repo, so it's a map, not a single
# value shared across both like the others.
locals {
  manufacturing_service_octopus_projects = {
    manufacturing-photo = "Photo"
    manufacturing-probe = "Probe"
  }
}

resource "gitea_repository_actions_secret" "octopus_server_url" {
  for_each   = toset(local.manufacturing_service_repos)
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  secret_name      = "OCTOPUS_SERVER_URL"
  secret_value     = "http://octopus:8080"
}

resource "gitea_repository_actions_secret" "octopus_api_key" {
  for_each   = toset(local.manufacturing_service_repos)
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  secret_name      = "OCTOPUS_API_KEY"
  secret_value     = var.octopus_api_key
}

resource "gitea_repository_actions_variable" "octopus_space" {
  for_each   = toset(local.manufacturing_service_repos)
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  variable_name    = "OCTOPUS_SPACE"
  # Deliberately the space's NAME ("Default"), not var.octopus_space_id
  # ("Spaces-1") — the workflow's "Push Build Information" step (the raw
  # Octopus CLI) accepts either, but OctopusDeploy/create-release-action
  # does a name-only lookup and failed with "No spaces exist with name
  # 'Spaces-1'" when given the Id instead.
  value = "Default"
}

resource "gitea_repository_actions_variable" "octopus_project" {
  for_each   = local.manufacturing_service_octopus_projects
  depends_on = [gitea_repository.manufacturing]

  repository_owner = var.gitea_username
  repository       = each.key
  variable_name    = "OCTOPUS_PROJECT"
  value            = each.value
}

# Tags manufacturing-photo and manufacturing-probe as v1.0.0 and kicks off
# their build-and-push workflow — no gitea provider resource manages git
# tags, so this is a null_resource + the Gitea API, matching this project's
# pattern for provider gaps elsewhere. Only manufacturing-photo/-probe:
# manufacturing-data-pipeline was removed, and the other 3 repos
# (manufacturing-apps/-configs/-terraform) have no build workflow at all.
#
# Idempotent by design, unlike this project's other always-run
# null_resources: it checks for the tag first and only creates + dispatches
# when it's actually missing (e.g. after a from-scratch rebuild, where the
# freshly seeded repos start with no tags at all) — a plain always-run
# trigger would kick off a rebuild on every single `terraform apply`, which
# isn't wanted once v1.0.0 already exists and has already built.
resource "null_resource" "tag_and_build_services" {
  depends_on = [
    gitea_repository_file.manufacturing,
    gitea_repository_actions_variable.registry,
    gitea_repository_actions_secret.registry_username,
    gitea_repository_actions_secret.registry_password,
    gitea_repository_actions_secret.octopus_server_url,
    gitea_repository_actions_secret.octopus_api_key,
    gitea_repository_actions_variable.octopus_space,
    gitea_repository_actions_variable.octopus_project,
  ]

  triggers = {
    # Re-checked (not re-run unconditionally) on every apply — see the
    # is-the-tag-already-there guard in the script itself.
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
        status=$(curl -sf -o /dev/null -w "%%{http_code}" \
          -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" \
          "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/tags/v1.0.0" || true)
        if [ "$${status}" = "200" ]; then
          echo "  $${repo}: v1.0.0 already tagged, skipping"
          continue
        fi
        echo "  $${repo}: creating v1.0.0 tag and dispatching build-and-push"
        curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" -X POST \
          "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/tags" \
          -H "Content-Type: application/json" \
          -d '{"tag_name":"v1.0.0","target":"main"}' >/dev/null
        # Belt-and-suspenders: the tag-push trigger alone was seen to not
        # reliably fire the Action for every repo in this project's
        # history — an explicit workflow_dispatch call guarantees it runs.
        curl -sf -u "$${GITEA_USERNAME}:$${GITEA_PASSWORD}" -X POST \
          "$${GITEA_URL}/api/v1/repos/$${GITEA_USERNAME}/$${repo}/actions/workflows/build-and-push.yaml/dispatches" \
          -H "Content-Type: application/json" \
          -d '{"ref":"main","inputs":{"version":"v1.0.0"}}' >/dev/null
      done
    EOT
  }
}
