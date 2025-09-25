provider "google" {
  project = var.project
  region  = var.location
}
provider "github" {
  owner = var.github_owner
  token = var.github_token
}
