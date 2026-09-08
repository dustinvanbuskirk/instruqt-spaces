resource "octopusdeploy_project_group" "it_manufacturing" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "IT Manufacturing"
  description = "Manufacturing applications with strict RFC and compliance requirements"
}

resource "octopusdeploy_project_group" "it_engineering" {
  space_id    = octopusdeploy_space.manufacturing.id
  name        = "IT Engineering"
  description = "Analytics and engineering applications with high-frequency deployments"
}