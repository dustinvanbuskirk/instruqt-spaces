output "space_id" {
  description = "The Id of the space these resources were created in (the instance's Default space, not a dedicated one)"
  value       = var.octopus_space_id
}

output "environment_ids" {
  description = "Environment IDs"
  value = {
    sqa                  = octopusdeploy_environment.sqa.id
    uat                  = octopusdeploy_environment.uat.id
    lead_site_production = octopusdeploy_environment.lead_site_production.id
    production           = octopusdeploy_environment.production.id
  }
}

output "tenant_ids" {
  description = "Tenant IDs"
  value = {
    fab_10n = octopusdeploy_tenant.fab_10n.id
    fab_11  = octopusdeploy_tenant.fab_11.id
    fab_15  = octopusdeploy_tenant.fab_15.id
    fab_16  = octopusdeploy_tenant.fab_16.id
    mmp     = octopusdeploy_tenant.mmp.id
  }
}

output "project_ids" {
  description = "Project IDs"
  value = {
    photo = octopusdeploy_project.photo.id
    probe = octopusdeploy_project.probe.id
  }
}

output "lifecycle_ids" {
  description = "Lifecycle IDs"
  value = {
    manufacturing = octopusdeploy_lifecycle.manufacturing.id
    engineering   = octopusdeploy_lifecycle.engineering.id
  }
}

output "tag_set_ids" {
  description = "Tag set IDs"
  value = {
    region        = octopusdeploy_tag_set.region.id
    facility_type = octopusdeploy_tag_set.facility_type.id
    deployment    = octopusdeploy_tag_set.deployment.id
  }
}

output "demo_summary" {
  description = "Summary of created demo resources"
  value = {
    environments_created = 4
    tenants_created     = 5
    projects_created    = 2
    lifecycles_created  = 2
    project_groups      = 1
  }
}