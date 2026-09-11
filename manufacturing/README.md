# manufacturing

Terraform configuration and demo content for a complete Octopus Deploy +
Gitea + Argo CD manufacturing environment — Octopus's built-in **Default
space** (`Spaces-1`), populated with tenants, projects, lifecycles, and an
Argo CD app-of-apps, plus the 4 example service/config repos it seeds into
Gitea.

This whole repo (`instruqt-spaces`) is public and designed to be cloned as
one piece by an **Instruqt track's** boot-time setup script — see
`track_scripts/setup-track-image` in the `instruqt-advanced-training-gitops`
track repo, which clones this repo onto the track VM and runs
`terraform apply` against it. It can also be run against a local dev
instance the same way (see below).

## Layout

```
manufacturing/
├── terraform/     Terraform root module — apply this
├── apps/          Argo CD app-of-apps manifests (seeded into Gitea)
├── configs/       Per-tenant/environment Helm values (seeded into Gitea)
├── photo/         Photo service source (seeded into Gitea)
└── probe/         Probe service source (seeded into Gitea)
```

`terraform/gitea.tf` seeds `apps/`, `configs/`, `photo/`, and `probe/`
into Gitea as their own repos (`manufacturing-apps`, `manufacturing-configs`,
`manufacturing-photo`, `manufacturing-probe`), wires up their Gitea Actions
build workflows, and bootstraps the Argo CD app-of-apps that reads
`manufacturing-apps`/`manufacturing-configs` back out.

Full detail on what each Terraform resource is for — tenant lists, project
descriptions, design rules for this project — is in
[`terraform/README.md`](terraform/README.md).

## Resources created

| Resource | Count | Notes |
|---|---|---|
| Environments | 4 | SQA, UAT, Lead Site Production (Fab 11 only), Production |
| Project groups | 1 | IT Manufacturing |
| Projects | 2 | Photo, Probe |
| Lifecycles | 2 | Manufacturing (SQA → UAT → Lead Site Production → Production), Engineering |
| Tenants | 5 | Fab 10N, Fab 11, Fab 15, Fab 16, MMP |
| Tag sets / tags | 3 / 5 | Region (North America, Asia), FacilityType (Production, Testing), Deployment (LeadSite) |
| Tenant-project connections | 8 | Wires tenants to Photo and Probe |
| Argo CD Application | 1 | App-of-apps (`it-manufacturing-apps`), cascading into 24 per-tenant/environment child Applications |

## Running locally (against a Vagrant-generated instance)

For local development/testing, the sibling
[`instruqt-octopus-local-images/`](../../instruqt-octopus-local-images/)
project runs `vagrant up` against the same base image Instruqt uses, and
writes a `terraform.tfvars` with that instance's credentials:

```bash
cd terraform
terraform init
terraform plan  -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
terraform apply -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```

After applying:

```bash
terraform output          # everything
terraform output space_id
```

## Cleaning up

```bash
cd terraform
terraform destroy -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```
