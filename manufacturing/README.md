# manufacturing

Terraform configuration that builds a complete Octopus Deploy demo
environment for manufacturing operations, from a dedicated space
down to projects, tenants, and lifecycles.

Everything lives in [`octopus/`](octopus/) — a single Terraform root module.
There's no separate module to run first: applying `octopus/` creates its own
space and populates it in one `terraform apply`.

## Resources created

| Resource | Count | Notes |
|---|---|---|
| Space | 1 | "Manufacturing" — created fresh, not the shared `Spaces-1` |
| Environments | 3 | SQA, UAT, Production |
| Project groups | 2 | IT Manufacturing, IT Engineering |
| Projects | 3 | Photo Overlay Server, Data Pipeline, Probe OQC ADC |
| Lifecycles | 2 | Manufacturing (SQA → UAT → Production, with approvals), Engineering (high-frequency) |
| Channels | 2 | Stable (default) and Beta, both on Photo Overlay Server |
| Tenants | 15 | 14 Fab facilities + 1 SQA-only testing tenant |
| Tag sets / tags | 3 / 5 | Region (North America, Asia), FacilityType (Production, Testing), Deployment (LeadSite) |
| Tenant-project connections | 8 | Wires tenants to Photo Overlay Server and Probe OQC ADC across all three environments |

Full detail on what each resource is for — tenant lists, project
descriptions, recommended deployment processes, troubleshooting — is in
[`octopus/README.md`](octopus/README.md). This file covers the setup you'll
actually use day to day: running Terraform against the local instance that
`vagrant up` spins up.

## Running against the Vagrant-generated instance

[`instruqt-octopus-local-images/`](../../instruqt-octopus-local-images/) runs
`vagrant up` and, as one of its triggers, writes a `terraform.tfvars` with
that instance's server URL and API key (regenerated on every `vagrant up` —
safe to rerun). It also carries some Gitea/ArgoCD values used elsewhere that
this configuration doesn't declare as variables; Terraform will warn about
those as "undeclared variable" but they're harmless and can be ignored. It
also still sets `octopus_space_id = "Spaces-1"` from before this
configuration created its own space — that value goes unused now since
`octopus/` no longer accepts (or needs) an `octopus_space_id` variable.

From this repo:

```bash
cd octopus
terraform init
terraform plan  -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
terraform apply -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```

That last command is the one that actually creates everything listed above
in the local Octopus instance at `http://localhost:8080`.

After applying, grab the new space's Id (and anything else) from outputs:

```bash
terraform output space_id
terraform output          # everything
```

To point this at a different Octopus instance instead of the local Vagrant
one, use your own `terraform.tfvars` (see
[`octopus/terraform.tfvars.example`](octopus/terraform.tfvars.example)) or
export `OCTOPUS_SERVER_URL` / `OCTOPUS_API_KEY` and use `octopus/deploy.sh`.

## Cleaning up

```bash
cd octopus
terraform destroy -var-file=../../../instruqt-octopus-local-images/terraform.tfvars
```

**Warning**: this deletes the Manufacturing space itself along with
everything Terraform created inside it — be deliberate before running it.
