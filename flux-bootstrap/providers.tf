provider "github" {
  owner = var.github_owner
}

# v1.6: nested blocks as map arguments, no merge()
provider "flux" {
  kubernetes = {
    # important: revealing ~
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubeconfig_context
  }

  git = {
    url    = "ssh://git@github.com/${var.github_owner}/${var.github_repo}.git"
    branch = var.github_branch
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}
