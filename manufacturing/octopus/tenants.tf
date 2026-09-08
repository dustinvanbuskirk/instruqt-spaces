# Manufacturing facility tenants
resource "octopusdeploy_tenant" "fab_10n" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 10N"
  description = "Fab 10 North facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_11" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 11"
  description = "Fab 11 facility - Primary Lead Site"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name,
    octopusdeploy_tag.lead_site.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_15" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 15"
  description = "Fab 15 facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_16" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 16"
  description = "Fab 16 facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_16s" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 16S"
  description = "Fab 16S facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_10w" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 10W"
  description = "Fab 10 West facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_4" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 4"
  description = "Fab 4 facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "fab_6" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Fab 6"
  description = "Fab 6 facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "mmp" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MMP"
  description = "MMP facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "mmy" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MMY"
  description = "MMY facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "msb" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MSB"
  description = "MSB facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "msi" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MSI"
  description = "MSI facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "mtb" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MTB"
  description = "MTB facility"
  tenant_tags = [
    octopusdeploy_tag.region_asia.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "mxa" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MXA"
  description = "MXA facility"
  tenant_tags = [
    octopusdeploy_tag.region_north_america.canonical_tag_name,
    octopusdeploy_tag.facility_production.canonical_tag_name
  ]
}

resource "octopusdeploy_tenant" "mmt_sqa" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "MMT SQA"
  description = "MMT SQA testing tenant - SQA only"
  tenant_tags = [
    octopusdeploy_tag.facility_testing.canonical_tag_name
  ]
}