variable "octopus_server_url" {
  description = "Octopus Deploy server URL"
  type        = string
}

variable "octopus_api_key" {
  description = "Octopus Deploy API key"
  type        = string
  sensitive   = true
}

variable "space_name" {
  description = "Display name for the space this configuration creates and populates"
  type        = string
  default     = "Manufacturing"
}

variable "space_description" {
  type    = string
  default = "Manufacturing environments, projects, and tenants."
}

variable "space_managers_teams" {
  description = "Team Ids to make managers of the new space. ASSUMPTION TO VERIFY: every Octopus instance ships a built-in \"Administrators\" team with Id \"teams-administrators\" — replace this if your instance's admin team has a different Id, or add specific team/user Ids instead."
  type        = list(string)
  default     = ["teams-administrators"]
}