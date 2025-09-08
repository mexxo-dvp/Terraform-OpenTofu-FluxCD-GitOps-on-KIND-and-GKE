variable "github_owner" {
  type        = string
  description = "GitHub owner/org, напр.: mexxo-dvp"
  validation {
    condition     = length(var.github_owner) > 0
    error_message = "github_owner не може бути порожнім."
  }
}

variable "github_repo" {
  type        = string
  description = "Назва приватного GitOps репо, напр.: gitops"
  validation {
    condition     = length(var.github_repo) > 0
    error_message = "github_repo не може бути порожнім."
  }
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "Гілка GitOps репо"
}

variable "gitops_path" {
  type        = string
  default     = "./apps"
  description = "Підкаталог у GitOps-репо, куди комітяться маніфести Flux"
}

variable "kubeconfig_path" {
  type        = string
  description = <<EOT
Шлях до kubeconfig GKE, напр.:
~/.kube/config або /workspaces/sentinel-bot/infra/gke/.kube/gke-gke-flux.kubeconfig
EOT
  validation {
    condition     = length(var.kubeconfig_path) > 0
    error_message = "kubeconfig_path обов'язковий."
  }
}

# Явно фіксуємо правильний контекст (зональний europe-west1-b)
variable "kubeconfig_context" {
  type        = string
  default     = "gke_civil-pattern-466501-m8_europe-west1-b_gke-flux"
  description = "Kube-context для підключення до кластера"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "Classic PAT зі scope: repo"
  validation {
    condition     = length(var.github_token) > 0
    error_message = "github_token обов'язковий (додай як змінну або у tfvars)."
  }
}
