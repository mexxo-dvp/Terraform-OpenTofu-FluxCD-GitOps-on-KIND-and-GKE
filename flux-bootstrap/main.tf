# --- Ключ для доступу до приватного GitOps-репо по SSH (deploy key) ---
resource "tls_private_key" "flux" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "flux" {
  repository = var.github_repo
  title      = "gitops:flux"
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}

# --- Bootstrap Flux у кластері + коміт маніфестів у GitOps-репо ---
resource "flux_bootstrap_git" "this" {
  # де в репозиторії зберігаються маніфести кластера
  path = var.gitops_path

  # куди інсталювати Flux у кластері
  namespace            = "flux-system"
  keep_namespace       = false
  network_policy       = true
  watch_all_namespaces = true

  # версія компонентів Flux, що підніметься в кластері та закомітиться у репо
  version = "v2.6.4"

  # компоненти Flux
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

  # Git-маніфести з Flux (зробить коміт у твій GitOps-репо через SSH)
  delete_git_manifests = true
  embedded_manifests   = false

  depends_on = [
    github_repository_deploy_key.flux
  ]
}
