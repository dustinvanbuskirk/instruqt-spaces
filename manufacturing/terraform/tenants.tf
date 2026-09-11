# Manufacturing facility tenants — reduced to the 5 facilities actually
# connected to a project (see tenant-project-connections.tf): the other 10
# facilities Octopus doesn't deploy anything to didn't need to exist here.
resource "octopusdeploy_tenant" "fab_10n" {
  space_id    = var.octopus_space_id
  name        = "Fab 10N"
  description = "Fab 10 North facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_11" {
  space_id    = var.octopus_space_id
  name        = "Fab 11"
  description = "Fab 11 facility - Primary Lead Site"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name,
    octopusdeploy_tag.lead_site.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_15" {
  space_id    = var.octopus_space_id
  name        = "Fab 15"
  description = "Fab 15 facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_16" {
  space_id    = var.octopus_space_id
  name        = "Fab 16"
  description = "Fab 16 facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "mmp" {
  space_id    = var.octopus_space_id
  name        = "MMP"
  description = "MMP facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}
