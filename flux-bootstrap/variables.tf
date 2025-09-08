variable "github_owner" {
  type        = string
  description = "GitHub owner/org"
  validation {
    condition     = length(var.github_owner) > 0
    error_message = "github_owner cannot be empty."
  }
}

variable "github_repo" {
  type        = string
  description = "name of a private GitOps repo, e.g.: gitops"
  validation {
    condition     = length(var.github_repo) > 0
    error_message = "github_repo cannot be empty."
  }
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "GitOps repo branch"
}

variable "gitops_path" {
  type        = string
  default     = "./apps"
  description = "Subdirectory in the GitOps repo where Flux manifests are committed"
}

variable "kubeconfig_path" {
  type        = string
  description = <<EOT
The path to kubeconfig GKE, for example.:
~/.kube/config або /workspaces/sentinel-bot/infra/gke/.kube/gke-gke-flux.kubeconfig
EOT
  validation {
    condition     = length(var.kubeconfig_path) > 0
    error_message = "kubeconfig_path is required."
  }
}

# Explicitly fix the correct context (zone europe-west1-b)
variable "kubeconfig_context" {
  type        = string
  default     = "gke_civil-pattern-466501-m8_europe-west1-b_gke-flux"
  description = "Kube-context for connecting to the cluster"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "Classic PAT from scope: repo"
  validation {
    condition     = length(var.github_token) > 0
    error_message = "github_token is required (add as a variable or in tfvars)."
  }
}
