output "space_id" {
  description = "The Id of the created Manufacturing space"
  value       = octopusdeploy_space.manufacturing.id
}

output "space_name" {
  value = octopusdeploy_space.manufacturing.name
}

output "space_slug" {
  value = octopusdeploy_space.manufacturing.slug
}

output "environment_ids" {
  description = "Environment IDs"
  value = {
    sqa        = octopusdeploy_environment.sqa.id
    uat        = octopusdeploy_environment.uat.id
    production = octopusdeploy_environment.production.id
  }
}

output "tenant_ids" {
  description = "Tenant IDs"
  value = {
    fab_10n  = octopusdeploy_tenant.fab_10n.id
    fab_10w  = octopusdeploy_tenant.fab_10w.id
    fab_11   = octopusdeploy_tenant.fab_11.id
    fab_15   = octopusdeploy_tenant.fab_15.id
    fab_16   = octopusdeploy_tenant.fab_16.id
    fab_16s  = octopusdeploy_tenant.fab_16s.id
    fab_4    = octopusdeploy_tenant.fab_4.id
    fab_6    = octopusdeploy_tenant.fab_6.id
    mmp      = octopusdeploy_tenant.mmp.id
    mmy      = octopusdeploy_tenant.mmy.id
    msb      = octopusdeploy_tenant.msb.id
    msi      = octopusdeploy_tenant.msi.id
    mtb      = octopusdeploy_tenant.mtb.id
    mxa      = octopusdeploy_tenant.mxa.id
    mmt_sqa  = octopusdeploy_tenant.mmt_sqa.id
  }
}

output "project_ids" {
  description = "Project IDs"
  value = {
    photo_overlay_server = octopusdeploy_project.photo_overlay_server.id
    data_pipeline        = octopusdeploy_project.data_pipeline.id
    probe_oqc_adc        = octopusdeploy_project.probe_oqc_adc.id
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
    environments_created = 3
    tenants_created     = 15
    projects_created    = 3
    lifecycles_created  = 2
    project_groups      = 2
  }
}