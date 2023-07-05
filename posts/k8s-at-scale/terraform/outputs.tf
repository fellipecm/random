output "api_endpoints" {
  description = "The endpoints for the Kubernetes API server"
  value       = ["${linode_lke_cluster.test.api_endpoints}"]
}

output "kubeconfig" {
  description = "The base64 encoded kubeconfig for the Kubernetes cluster"
  value       = ["${linode_lke_cluster.test.kubeconfig}"]
  sensitive   = true
}

output "dashboard_url" {
  description = "The Kubernetes Dashboard access URL for this cluster"
  value       = ["${linode_lke_cluster.test.dashboard_url}"]
}
