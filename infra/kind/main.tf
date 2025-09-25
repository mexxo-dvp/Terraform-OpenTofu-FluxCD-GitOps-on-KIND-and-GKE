module "kind_cluster" {
  source = "github.com/den-vasyliev/tf-kind-cluster"
}

module "tls_private_key" {
  source = "github.com/den-vasyliev/tf-hashicorp-tls-keys"
}

resource "github_repository_deploy_key" "flux_ro" {
  repository = var.github_repo
  title      = "flux-readonly"
  key        = module.tls_private_key.public_key_openssh
  read_only  = true
}

module "flux_bootstrap" {
  source            = "github.com/den-vasyliev/tf-fluxcd-flux-bootstrap"
  github_repository = "${var.github_owner}/${var.github_repo}"
  github_token      = var.github_token
  private_key       = module.tls_private_key.private_key_pem
  config_path       = pathexpand("~/.kube/config")
  target_path       = var.flux_target_path
}
