resource "octopusdeploy_project_group" "it_manufacturing" {
  space_id    = var.octopus_space_id
  name        = "IT Manufacturing"
  description = "Manufacturing applications with strict RFC and compliance requirements"
}