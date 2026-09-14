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

# Both projects deploy to every tenant in Lead Site Production/Production
# concurrently (see the release challenges' "select every tenant offered"
# deploys) — Octopus's default deployment mutex serializes deployments
# targeting the same machine/tenant combination, which can queue those
# concurrent deployments instead of running them in parallel. Explicit
# "False" here documents the intended behavior rather than leaving it at
# whatever this box's own default happens to be.
resource "octopusdeploy_variable" "photo_bypass_deployment_mutex" {
  owner_id = octopusdeploy_project.photo.id
  name     = "OctopusBypassDeploymentMutex"
  type     = "String"
  value    = "False"
}

resource "octopusdeploy_variable" "probe_bypass_deployment_mutex" {
  owner_id = octopusdeploy_project.probe.id
  name     = "OctopusBypassDeploymentMutex"
  type     = "String"
  value    = "False"
}