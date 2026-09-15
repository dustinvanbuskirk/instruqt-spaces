# Connect Photo to production tenants
resource "octopusdeploy_tenant_project" "photo_fab_10n" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_10n.id
  project_id = octopusdeploy_project.photo.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_fab_11" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_11.id
  project_id = octopusdeploy_project.photo.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.lead_site_production.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_fab_15" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_15.id
  project_id = octopusdeploy_project.photo.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_fab_16" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_16.id
  project_id = octopusdeploy_project.photo.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_mmp" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.mmp.id
  project_id = octopusdeploy_project.photo.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

# Connect Probe to every tenant (matches photo — was missing fab_16/mmp
# entirely, confirmed live: those two tenants never had a probe project
# connection at all, not merely an unhealthy one).
resource "octopusdeploy_tenant_project" "probe_fab_10n" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_10n.id
  project_id = octopusdeploy_project.probe.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "probe_fab_11" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_11.id
  project_id = octopusdeploy_project.probe.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.lead_site_production.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "probe_fab_15" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_15.id
  project_id = octopusdeploy_project.probe.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "probe_fab_16" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.fab_16.id
  project_id = octopusdeploy_project.probe.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "probe_mmp" {
  space_id   = var.octopus_space_id
  tenant_id  = octopusdeploy_tenant.mmp.id
  project_id = octopusdeploy_project.probe.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}