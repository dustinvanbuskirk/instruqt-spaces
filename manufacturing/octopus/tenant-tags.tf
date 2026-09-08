# Tag Sets and Tags for organizing tenants
resource "octopusdeploy_tag_set" "region" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Region"
  description = "Geographic region for manufacturing facilities"
  sort_order  = 1
}

resource "octopusdeploy_tag" "region_north_america" {
  name              = "North America"
  tag_set_id        = octopusdeploy_tag_set.region.id
  tag_set_space_id  = octopusdeploy_space.manufacturing.id
  color             = "#2E5C8A"
  description       = "North American facilities"
  sort_order        = 1
}

resource "octopusdeploy_tag" "region_asia" {
  name              = "Asia"
  tag_set_id        = octopusdeploy_tag_set.region.id
  tag_set_space_id  = octopusdeploy_space.manufacturing.id
  color             = "#8A2E5C"
  description       = "Asian facilities"
  sort_order        = 2
}

resource "octopusdeploy_tag_set" "facility_type" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "FacilityType"
  description = "Type of facility"
  sort_order  = 2
}

resource "octopusdeploy_tag" "facility_production" {
  name              = "Production"
  tag_set_id        = octopusdeploy_tag_set.facility_type.id
  tag_set_space_id  = octopusdeploy_space.manufacturing.id
  color             = "#36A64F"
  description       = "Production manufacturing facility"
  sort_order        = 1
}

resource "octopusdeploy_tag" "facility_testing" {
  name              = "Testing"
  tag_set_id        = octopusdeploy_tag_set.facility_type.id
  tag_set_space_id  = octopusdeploy_space.manufacturing.id
  color             = "#F39C12"
  description       = "Testing-only facility"
  sort_order        = 2
}

resource "octopusdeploy_tag_set" "deployment" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "Deployment"
  description = "Deployment-related tags"
  sort_order  = 3
}

resource "octopusdeploy_tag" "lead_site" {
  name              = "LeadSite"
  tag_set_id        = octopusdeploy_tag_set.deployment.id
  tag_set_space_id  = octopusdeploy_space.manufacturing.id
  color             = "#E74C3C"
  description       = "Primary lead site for canary deployments"
  sort_order        = 1
}
