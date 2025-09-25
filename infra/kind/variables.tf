variable "cluster_name" {
  type    = string
  default = "kind-flux"
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

variable "flux_target_path" {
  type    = string
  default = "gitops/clusters/kind"
}
