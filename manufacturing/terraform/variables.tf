variable "octopus_server_url" {
  description = "Octopus Deploy server URL"
  type        = string
}

variable "octopus_api_key" {
  description = "Octopus Deploy API key"
  type        = string
  sensitive   = true
}

variable "octopus_space_id" {
  description = "Space to create every resource in — defaults to the instance's built-in Default space rather than a dedicated one this configuration used to create itself."
  type        = string
  default     = "Spaces-1"
}

variable "gitea_url" {
  description = "Gitea base API URL, reachable from the host running Terraform (not the same as the in-cluster \"gitea:3000\" hostname baked into seeded repoURLs)"
  type        = string
}

variable "gitea_username" {
  description = "Gitea account that owns the seeded repositories"
  type        = string
}

variable "gitea_password" {
  type      = string
  sensitive = true
}

variable "argocd_server_addr" {
  description = "Argo CD API server address reachable from the host running Terraform (host:port, no scheme)"
  type        = string
}

variable "argocd_username" {
  description = "Argo CD account Terraform authenticates as — also used to mint a fresh auth token via the data.external.argocd_token source in providers.tf"
  type        = string
  default     = "octopus"
}

variable "argocd_password" {
  description = "Password for var.argocd_username, used to mint a fresh Argo CD auth token (see data.external.argocd_token in providers.tf)"
  type        = string
  sensitive   = true
}

variable "argocd_insecure" {
  type    = bool
  default = true
}

variable "argocd_plain_text" {
  type    = bool
  default = true
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig for the KinD cluster, used by the local-exec kubectl calls in argocd.tf/bootstrap-cleanup.tf. Defaults to /root/.kube/config — kind's own default kubeconfig location (no --kubeconfig flag is ever passed to `kind create cluster` on this box, so it writes/merges there), which Terraform finds for free when it runs directly on that box (an Instruqt track sandbox). Note: ~/kind-cluster/kind-config.yaml is a *different* file — the cluster-creation config passed to `kind create cluster --config`, not a kubeconfig at all — and pointing kubectl at it fails immediately. Local Vagrant dev runs Terraform from the separate Windows host instead, so it overrides this to that host's own Vagrantfile-generated kubeconfig file (a socat-relayed path, not a copy of this same file)."
  type        = string
  default     = "/root/.kube/config"
}