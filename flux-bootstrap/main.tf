# --- Key for accessing private GitOps repo via SSH (deploy key) ---
resource "tls_private_key" "flux" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "flux" {
  repository = var.github_repo
  title      = "gitops:flux"
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}

# --- Bootstrap Flux in cluster + commit manifests to GitOps repo ---
resource "flux_bootstrap_git" "this" {
# where in the repository the cluster manifests are stored
  path = var.gitops_path

# where to install Flux in the cluster
  namespace            = "flux-system"
  keep_namespace       = false
  network_policy       = true
  watch_all_namespaces = true

# version of Flux components that will be pushed to the cluster and committed to the repo
  version = "v2.6.4"

# Flux components
  components = [
    "source-controller",
    "kustomize-controller",
    "helm-controller",
    "notification-controller",
  ]

  # housekeeping
  interval       = "1m0s"
  log_level      = "info"
  cluster_domain = "cluster.local"

# Git manifests with Flux (will commit to your GitOps repo via SSH)
  delete_git_manifests = true
  embedded_manifests   = false

  depends_on = [
    github_repository_deploy_key.flux
  ]
}
