# Manufacturing Demo — Octopus Deploy, Gitea, Argo CD

This Terraform configuration builds the entire Manufacturing demo against
an environment that already has Octopus Deploy, Gitea, and a KinD-hosted
Argo CD running — either an **Instruqt track sandbox** (base image
`octopus/2026-3-base`) or a **local Vagrant/VirtualBox appliance** (the
sibling `instruqt-octopus-local-images` project, which mirrors the same
base image for local dev/testing). It is not a generic "point Terraform at
any Octopus instance" config — it assumes one of those two environments
and their baked-in Gitea/Argo CD.

It configures, in Octopus's built-in **Default space (`Spaces-1`)** — not a
dedicated space — plus Gitea and Argo CD:

- 4 Environments: SQA → UAT → **Lead Site Production** (Fab 11 only) → Production
- 5 Tenants: Fab 10N, Fab 11, Fab 15, Fab 16, MMP
- 2 Projects: Photo, Probe (both tenanted)
- 1 Project Group (IT Manufacturing) / 2 Lifecycles (Manufacturing, Engineering)
- Tenant tags and tenant↔project environment connections
- 4 Gitea repositories, seeded from sibling directories in this same repo
  (see below), with Actions secrets/variables wired for building and
  pushing images to Gitea's own container registry and creating Octopus
  releases
- The Argo CD app-of-apps Application (`it-manufacturing-apps`), which
  cascades into one child Application per tenant/environment/service
- Self-healing cleanup for things that can't be expressed as plain
  create-only resources: pre-existing "Production"/"Default Project Group"
  conflicts on a freshly-baked box, Argo CD RBAC for the `octopus` service
  account, and removal of the box's own unrelated sample Argo CD apps

## Repository layout

This Terraform root lives at `instruqt-spaces/manufacturing/terraform/`.
The 4 repos it seeds into Gitea are sibling directories right next to it,
in this same repo:

```
instruqt-spaces/manufacturing/
├── terraform/     <- this Terraform root
├── apps/          seeded into Gitea repo "manufacturing-apps"
├── configs/       seeded into Gitea repo "manufacturing-configs"
├── photo/         seeded into Gitea repo "manufacturing-photo"
└── probe/         seeded into Gitea repo "manufacturing-probe"
```

Each directory's entire file tree is pushed into its matching Gitea repo
via `gitea_repository_file` resources (`gitea.tf`) — one commit per file.
Local edits under any of these directories need a `terraform apply` from
`terraform/` to actually reach Gitea.

> If you've ever run `terraform init`/`apply` directly inside one of these
> sibling directories, its `.terraform/` directory is automatically
> excluded from what gets seeded — a provider binary in there isn't valid
> UTF-8 and will otherwise break the `file()` call in `gitea.tf`.

## Running as an Instruqt track

This whole `instruqt-spaces` repo is public and gets cloned as one piece by
an Instruqt track's boot-time setup script — see
`track_scripts/setup-track-image` in the `instruqt-advanced-training-gitops`
track repo. That script:

1. Reads 3 track secrets (`OCTOPUS_API_KEY`, `GITEA_PASSWORD`,
   `ARGOCD_PASSWORD`) — configured once in the Instruqt UI (Settings →
   Secrets) and granted to the track via its `config.yml`. These are fixed,
   known values (the same ones the box bakes in), never committed to
   either repo.
2. Clones this repo to the sandbox VM.
3. Generates a fresh Argo CD API token for the `octopus` account (tokens
   aren't baked in — they're minted per login).
4. Writes `terraform/terraform.tfvars` and runs `terraform apply`.

Nothing here needs editing to support that flow — it Just Works as long as
this repo stays public and the 3 secrets exist with the right names.

## Running locally (against a Vagrant-generated instance)

For local development/testing, the sibling
[`instruqt-octopus-local-images/`](../../instruqt-octopus-local-images/)
project runs `vagrant up` against the same base image, and writes a
`terraform.tfvars` with that instance's credentials automatically:

```bash
cd terraform
terraform init
terraform plan  -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
terraform apply -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```

The generated `terraform.tfvars` already sets `kubeconfig_path` to the
Vagrantfile-generated `kubeconfig` file's absolute path — its own default
(`/root/.kube/config`, kind's own default kubeconfig location) assumes
Terraform is running on the same box as the KinD cluster (true on an
Instruqt sandbox), which isn't the case for local dev (Terraform runs on
the Windows host against the separate Vagrant VM). If you're running
Terraform from WSL instead of git-bash/PowerShell, override it with the
WSL-mounted equivalent path
(e.g. `-var kubeconfig_path=/mnt/c/Users/<you>/src/instruqt-octopus-local-images/kubeconfig`).

A from-scratch apply creates on the order of 200+ resources (most of it is
the per-file `gitea_repository_file` seeding) and can take several minutes.

Access the running services from the host: Octopus Deploy at
`http://localhost:8080`, Gitea at `http://localhost:3000` (user `admin`),
Argo CD at `https://localhost:9443` (user `octopus`) — credentials for all
three are in the generated `terraform.tfvars`.

### Full teardown and rebuild from scratch (local Vagrant only)

```bash
# 1. Destroy Terraform-managed resources while the VM is still up.
cd instruqt-spaces/manufacturing/terraform
terraform destroy -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```
```powershell
# 2. Destroy the VM (PowerShell — vagrant/VBoxManage commands should run
#    from PowerShell, not git-bash, on this machine)
cd instruqt-octopus-local-images
vagrant destroy -f
```
```bash
# 3. Clear local Terraform state — meaningless once the VM is gone.
cd instruqt-spaces/manufacturing/terraform
rm -rf .terraform terraform.tfstate terraform.tfstate.backup *.tfplan
```
```powershell
# 4. Bring the VM back up (PowerShell)
cd instruqt-octopus-local-images
vagrant up
```
```bash
# 5. Re-initialize and apply against the fresh environment
cd instruqt-spaces/manufacturing/terraform
terraform init
terraform apply -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```

A couple of `terraform destroy` errors are expected and harmless in step 1
if you hit them — Octopus won't let the API delete a project's built-in
"Default" channel, and an occasional stale tenant reference can no-op —
since step 2 destroys the underlying data regardless.

## Outputs

```bash
terraform output                  # everything
terraform output space_id
terraform output environment_ids
terraform output tenant_ids
terraform output project_ids
terraform output lifecycle_ids
terraform output tag_set_ids
terraform output demo_summary
```

## Deployment processes

The two Octopus projects currently have **no deployment process steps
defined** — release creation via the Gitea Actions workflows
(`manufacturing-photo`/`manufacturing-probe`'s `.gitea/workflows/build-and-push.yaml`)
will fail at the "Create Release" step until this is built out. The actual
Kubernetes deployment is handled by Argo CD's GitOps sync from
`manufacturing-configs`, not by Octopus directly — the deployment process
still to be designed here needs to fit that model (e.g. a script step that
updates the target tenant/environment's `values.yaml` image tag in
`manufacturing-configs` via the Gitea API, letting Argo CD pick it up),
and, per this project's standing rule below, must be built in Terraform
rather than configured by hand in the Octopus UI.

## Design rules for this project

- **Everything is Terraform.** Any fix or piece of state — environment/name
  conflicts on a freshly-baked box, RBAC gaps, cleanup of baked-in sample
  content — must be encoded as a Terraform resource (a `null_resource` +
  `local-exec` where the underlying provider has no resource for it), not
  performed ad hoc against the running instance. This config is meant to be
  applied against a from-scratch VM/sandbox over and over and always
  complete cleanly.
- **Providers are fixed**: `OctopusDeploy/octopusdeploy`, `go-gitea/gitea`,
  `argoproj-labs/argocd` (not `OctopusDeployLabs/octopusdeploy`, which is
  unmaintained). Introducing another provider needs a reason.
- **Space is `Spaces-1` (Default)** — this config does not create or target
  a dedicated Octopus space.
- **Credentials are never committed.** The Octopus API key, Gitea password,
  and Argo CD password are fixed/known values, but they live only in
  Instruqt track secrets (or the Vagrant-generated `terraform.tfvars`,
  which is gitignored) — never hardcoded in any `.tf` file or script.

## Troubleshooting

- **`kubectl`/the `local-exec` provisioners can't reach the cluster**: these
  resources expect `KUBECONFIG=/root/.kube/config` to already point at a
  working KinD cluster — `track_scripts/setup-track-image` (Instruqt) or
  `provision/verify-core-services.sh` (local Vagrant) is responsible for
  writing it there via `kind export kubeconfig` before Terraform runs.
- **`file()` error under `.terraform/providers/...`**: a sibling content
  directory (`apps/`, `configs/`, `photo/`, `probe/`) has its own
  `.terraform/` from having `terraform init` run inside it directly —
  already filtered out in `gitea.tf`'s `manufacturing_repo_files`, but a
  good sign this happened if you see it reappear.
- **`No spaces exist with name 'Spaces-1'`** (in a Gitea Actions workflow
  run): `OctopusDeploy/create-release-action` resolves `space` by name, not
  ID — the `OCTOPUS_SPACE` Gitea variable is deliberately set to `"Default"`
  (see `gitea.tf`), not `var.octopus_space_id`.

## Documentation

- [Octopus Terraform Provider](https://registry.terraform.io/providers/OctopusDeploy/octopusdeploy/latest/docs)
- [Gitea Terraform Provider](https://registry.terraform.io/providers/go-gitea/gitea/latest/docs)
- [Argo CD Terraform Provider](https://registry.terraform.io/providers/argoproj-labs/argocd/latest/docs)
- [Octopus Multi-Tenancy](https://octopus.com/docs/tenants)
- [Octopus Lifecycles](https://octopus.com/docs/releases/lifecycles)
