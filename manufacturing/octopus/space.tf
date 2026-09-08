# space.tf
#
# Creates the "Manufacturing" space that the rest of this configuration
# populates with environments, projects, tenants, lifecycles, etc. This used
# to just be Spaces-1 (the instance's default space, shared with whatever
# else lives there) — this resource gives the project its own dedicated
# space instead.
resource "octopusdeploy_space" "manufacturing" {
  name        = var.space_name
  description = var.space_description

  is_default            = false
  is_task_queue_stopped = false

  space_managers_teams = var.space_managers_teams
}
