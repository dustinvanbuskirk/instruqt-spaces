# Connect Photo Overlay Server to production tenants
resource "octopusdeploy_tenant_project" "photo_overlay_fab_10n" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_10n.id
  project_id      = octopusdeploy_project.photo_overlay_server.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_overlay_fab_11" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_11.id
  project_id      = octopusdeploy_project.photo_overlay_server.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_overlay_fab_15" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_15.id
  project_id      = octopusdeploy_project.photo_overlay_server.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_overlay_fab_16" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_16.id
  project_id      = octopusdeploy_project.photo_overlay_server.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "photo_overlay_mmp" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.mmp.id
  project_id      = octopusdeploy_project.photo_overlay_server.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

# Connect Probe OQC ADC to subset of tenants
resource "octopusdeploy_tenant_project" "probe_oqc_fab_10n" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_10n.id
  project_id      = octopusdeploy_project.probe_oqc_adc.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "probe_oqc_fab_11" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_11.id
  project_id      = octopusdeploy_project.probe_oqc_adc.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}

resource "octopusdeploy_tenant_project" "probe_oqc_fab_15" {
  space_id        = octopusdeploy_space.manufacturing.id
  tenant_id       = octopusdeploy_tenant.fab_15.id
  project_id      = octopusdeploy_project.probe_oqc_adc.id
  environment_ids = [
    octopusdeploy_environment.sqa.id,
    octopusdeploy_environment.uat.id,
    octopusdeploy_environment.production.id
  ]
}