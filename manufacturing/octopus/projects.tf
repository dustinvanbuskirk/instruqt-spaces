resource "octopusdeploy_project" "photo_overlay_server" {
  space_id                          = octopusdeploy_space.manufacturing.id
  name                              = "Photo Overlay Server"
  description                       = "Manufacturing floor application for photo overlay processing - Deployed to all Fab facilities"
  lifecycle_id                      = octopusdeploy_lifecycle.manufacturing.id
  project_group_id                  = octopusdeploy_project_group.it_manufacturing.id
  tenanted_deployment_participation = "Tenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = true
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}

resource "octopusdeploy_project" "data_pipeline" {
  space_id                          = octopusdeploy_space.manufacturing.id
  name                              = "Data Pipeline"
  description                       = "Central data aggregation and analytics pipeline for IT Engineering"
  lifecycle_id                      = octopusdeploy_lifecycle.engineering.id
  project_group_id                  = octopusdeploy_project_group.it_engineering.id
  tenanted_deployment_participation = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = true
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}

resource "octopusdeploy_project" "probe_oqc_adc" {
  space_id                          = octopusdeploy_space.manufacturing.id
  name                              = "Probe OQC ADC"
  description                       = "Probe Outgoing Quality Control Automated Data Collection - Pull deployment model"
  lifecycle_id                      = octopusdeploy_lifecycle.manufacturing.id
  project_group_id                  = octopusdeploy_project_group.it_manufacturing.id
  tenanted_deployment_participation = "Tenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = true
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}