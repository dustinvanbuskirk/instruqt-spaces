resource "octopusdeploy_lifecycle" "manufacturing" {
  space_id    = var.octopus_space_id
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

  # Optional: only Fab 11 (the primary lead site) actually deploys here —
  # see tenant-project-connections.tf, where only fab_11's connections
  # include this environment's Id. Every other tenant skips straight from
  # UAT to Production.
  phase {
    name                                  = "Lead Site Production"
    is_optional_phase                     = true
    minimum_environments_before_promotion = 0
    optional_deployment_targets           = [octopusdeploy_environment.lead_site_production.id]
  }

  phase {
    name                                  = "Production"
    is_optional_phase                     = false
    minimum_environments_before_promotion = 0
    optional_deployment_targets           = [octopusdeploy_environment.production.id]
  }
}

resource "octopusdeploy_lifecycle" "engineering" {
  space_id    = var.octopus_space_id
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