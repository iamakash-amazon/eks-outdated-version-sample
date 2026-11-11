output "cluster_name" {
  description = "Name of the sample EKS cluster."
  value       = aws_eks_cluster.sample.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint for the sample cluster."
  value       = aws_eks_cluster.sample.endpoint
}
