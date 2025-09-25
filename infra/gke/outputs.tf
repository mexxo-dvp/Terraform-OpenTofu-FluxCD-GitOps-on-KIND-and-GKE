output "kubeconfig_path" {
  value = abspath("${path.root}/.kube/gke-${var.cluster_name}.kubeconfig")
}
