# providers.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeploy/octopusdeploy"
      version = "~> 1.5"
    }
  }
}

# Deliberately NO space_id here. This configuration creates its own
# "Manufacturing" space (see space.tf) as well as populating it, and a
# provider block can't be configured with a value computed from a resource
# in the same apply. Instead, every space-scoped resource below sets its own
# space_id = octopusdeploy_space.manufacturing.id, which the octopusdeploy
# provider supports as a per-resource override of the (here, unset)
# provider-level space_id.
provider "octopusdeploy" {
  address = var.octopus_server_url
  api_key = var.octopus_api_key
}