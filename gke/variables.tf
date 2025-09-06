variable "project" {
  type = string
}

variable "location" {
  type    = string
  default = "europe-west1" # region;
}

variable "cluster_name" {
  type    = string
  default = "gke-flux"
}

variable "pool_name" {
  type    = string
  default = "default-pool"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "github_owner" {
  type    = string
  default = "mexxo-dvp"
}

variable "github_repo" {
  type    = string
  default = "sentinel-bot"
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "target_path" {
  type    = string
  default = "gitops/clusters/gke"
}
