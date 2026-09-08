# Environments
resource "octopusdeploy_environment" "sqa" {
  space_id                     = octopusdeploy_space.manufacturing.id
  name                         = "SQA"
  description                  = "Software Quality Assurance environment for testing"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

resource "octopusdeploy_environment" "uat" {
  space_id                     = octopusdeploy_space.manufacturing.id
  name                         = "UAT"
  description                  = "User Acceptance Testing / Beta environment"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

resource "octopusdeploy_environment" "production" {
  space_id                     = octopusdeploy_space.manufacturing.id
  name                         = "Production"
  description                  = "Production environment for live manufacturing operations"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}