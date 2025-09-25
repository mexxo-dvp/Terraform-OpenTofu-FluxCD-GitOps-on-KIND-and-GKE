output "kubeconfig_path" {
  value = pathexpand("~/.kube/config")
}
