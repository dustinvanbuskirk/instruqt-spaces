resource "octopusdeploy_lifecycle" "manufacturing" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Manufacturing Lifecycle"
  description = "SQA → UAT → Production lifecycle for manufacturing applications"

  release_retention_with_strategy {
    quantity_to_keep = 10
    unit             = "Days"
    strategy         = "Count"
  }

  tentacle_retention_with_strategy {
    quantity_to_keep = 5
    unit             = "Days"
    strategy         = "Count"
  }

  phase {
    name                                  = "SQA"
    is_optional_phase                     = false
    minimum_environments_before_promotion = 1
    optional_deployment_targets           = [octopusdeploy_environment.sqa.id]
  }

  phase {
    name                                  = "UAT"
    is_optional_phase                     = false
    minimum_environments_before_promotion = 1
    optional_deployment_targets           = [octopusdeploy_environment.uat.id]
  }

  phase {
    name                                  = "Production"
    is_optional_phase                     = false
    minimum_environments_before_promotion = 0
    optional_deployment_targets           = [octopusdeploy_environment.production.id]
  }
}

resource "octopusdeploy_lifecycle" "engineering" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Engineering Lifecycle"
  description = "High-frequency deployment lifecycle for IT Engineering"

  release_retention_with_strategy {
    quantity_to_keep = 30
    unit             = "Days"
    strategy         = "Count"
  }

  tentacle_retention_with_strategy {
    quantity_to_keep = 10
    unit             = "Days"
    strategy         = "Count"
  }

  phase {
    name                                  = "SQA"
    is_optional_phase                     = false
    minimum_environments_before_promotion = 0
    optional_deployment_targets           = [octopusdeploy_environment.sqa.id]
  }

  phase {
    name                                  = "UAT"
    is_optional_phase                     = true
    minimum_environments_before_promotion = 0
    optional_deployment_targets           = [octopusdeploy_environment.uat.id]
  }

  phase {
    name                                  = "Production"
    is_optional_phase                     = false
    minimum_environments_before_promotion = 0
    optional_deployment_targets           = [octopusdeploy_environment.production.id]
  }
}