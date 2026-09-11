resource "octopusdeploy_project" "photo" {
  space_id                          = var.octopus_space_id
  name                              = "Photo"
  description                       = "Manufacturing demo service — deployed to all Fab facilities"
  lifecycle_id                      = octopusdeploy_lifecycle.manufacturing.id
  project_group_id                  = octopusdeploy_project_group.it_manufacturing.id
  tenanted_deployment_participation = "Tenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = true
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}

resource "octopusdeploy_project" "probe" {
  space_id                          = var.octopus_space_id
  name                              = "Probe"
  description                       = "Manufacturing demo service — pull deployment model"
  lifecycle_id                      = octopusdeploy_lifecycle.manufacturing.id
  project_group_id                  = octopusdeploy_project_group.it_manufacturing.id
  tenanted_deployment_participation = "Tenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = true
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}