#############################
# infra/gke/main.tf
#############################

############################################################
# 1) GKE cluster (zonal: less SSD quota requirements)
#    - GOOGLE_REGION   = europe-west1
#    - GOOGLE_LOCATION = europe-west1-b (зона)
############################################################
module "gke" {
  source = "github.com/mexxo-dvp/tf-google-gke-cluster"

  # GCP
  GOOGLE_PROJECT  = var.project
  GOOGLE_REGION   = var.region
  GOOGLE_LOCATION = var.location

  # Cluster/Pool
  GKE_CLUSTER_NAME = var.cluster_name
  GKE_POOL_NAME    = var.pool_name
  GKE_NUM_NODES    = var.node_count
  GKE_MACHINE_TYPE = var.machine_type

  # disk config:
  # GKE_DISK_TYPE = "pd-standard"
  # GKE_DISK_SIZE = 30
}

############################################################
# 2) TLS keys + deploy key from GitHub (RO for Flux)
############################################################
module "tls_private_key" {
  source = "github.com/den-vasyliev/tf-hashicorp-tls-keys"
}

resource "github_repository_deploy_key" "flux_ro_gke" {
  repository = var.github_repo
  title      = "flux-readonly-gke"
  key        = module.tls_private_key.public_key_openssh
  read_only  = true
}

############################################################
# 3) kubeconfig via official auth module → local file
############################################################
module "gke_auth_self" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project
  location     = var.location   # має збігатися із зоною вище
  cluster_name = var.cluster_name

  # ensure that the cluster has already been created
  depends_on = [module.gke]
}

resource "local_file" "kubeconfig" {
  content         = module.gke_auth_self.kubeconfig_raw
  filename        = abspath("${path.root}/.kube/gke-${var.cluster_name}.kubeconfig")
  file_permission = "0600"
}

############################################################
# 4) Flux bootstrap in GKE
############################################################
module "flux_bootstrap_gke" {
  source = "github.com/den-vasyliev/tf-fluxcd-flux-bootstrap"

  # GitHub
  github_repository = "${var.github_owner}/${var.github_repo}"
  github_token      = var.github_token
  private_key       = module.tls_private_key.private_key_pem

  # kubeconfig
  config_path = local_file.kubeconfig.filename

  target_path = var.target_path
}
