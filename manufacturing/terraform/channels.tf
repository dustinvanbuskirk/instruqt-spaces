# Channels for different release strategies
resource "octopusdeploy_channel" "photo_stable" {
  space_id     = var.octopus_space_id
  name         = "Stable"
  project_id   = octopusdeploy_project.photo.id
  description  = "Stable releases for production deployment"
  is_default   = true
  lifecycle_id = octopusdeploy_lifecycle.manufacturing.id
}

resource "octopusdeploy_channel" "photo_beta" {
  space_id     = var.octopus_space_id
  name         = "Beta"
  project_id   = octopusdeploy_project.photo.id
  description  = "Beta/pre-release versions for testing"
  is_default   = false
  lifecycle_id = octopusdeploy_lifecycle.manufacturing.id
}