#############################
# infra/gke/variables.tf
#############################

variable "project" {
  type        = string
  description = "GCP Project ID (e.g., civil-pattern-466501-m8)"
}

variable "region" {
  type        = string
  description = "GCP region (e.g., europe-west1)"
  default     = "europe-west1"
}

variable "location" {
  type        = string
  description = "GKE location: use ZONE for zonal cluster (e.g., europe-west1-b)"
  default     = "europe-west1-b"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster"
  default     = "gke-flux"
}

variable "pool_name" {
  type        = string
  description = "Name of the node pool"
  default     = "default-pool"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the pool"
  default     = 1
}

variable "machine_type" {
  type        = string
  description = "Machine type for GKE nodes"
  default     = "e2-standard-2"
}

variable "github_owner" {
  type        = string
  description = "GitHub owner/org (e.g., mexxo-dvp)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g., sentinel-bot)"
}

variable "github_token" {
  type        = string
  description = "GitHub PAT (Classic) with repo + admin:public_key scopes"
  sensitive   = true
}

variable "target_path" {
  type        = string
  description = "Path in the GitHub repository where Flux manifests will be stored (e.g., apps/)"
  default     = "apps/"
}
