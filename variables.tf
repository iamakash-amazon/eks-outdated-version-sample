variable "aws_region" {
  description = "AWS region for the sample cluster."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
  default     = "outdated-eks-sample"
}

variable "cluster_role_arn" {
  description = "ARN of an IAM role that EKS can assume to create the cluster."
  type        = string
}

variable "node_role_arn" {
  description = "ARN of an IAM role for the managed worker nodes."
  type        = string
}

variable "subnet_ids" {
  description = "At least two subnet IDs in the cluster VPC."
  type        = list(string)
}
