# Channels for different release strategies
resource "octopusdeploy_channel" "photo_overlay_stable" {
  space_id     = octopusdeploy_space.manufacturing.id
  name         = "Stable"
  project_id   = octopusdeploy_project.photo_overlay_server.id
  description  = "Stable releases for production deployment"
  is_default   = true
  lifecycle_id = octopusdeploy_lifecycle.manufacturing.id
}

resource "octopusdeploy_channel" "photo_overlay_beta" {
  space_id     = octopusdeploy_space.manufacturing.id
  name         = "Beta"
  project_id   = octopusdeploy_project.photo_overlay_server.id
  description  = "Beta/pre-release versions for testing"
  is_default   = false
  lifecycle_id = octopusdeploy_lifecycle.manufacturing.id
}