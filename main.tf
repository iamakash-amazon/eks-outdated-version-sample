terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Upgraded from 1.24 to 1.31, the oldest version Amazon EKS still offers
# (1.24-1.30 are past end of extended support and were auto-upgraded by EKS).
# Continue one minor version at a time; see UPGRADE-STEPS.md.
resource "aws_eks_cluster" "sample" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.31"

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

resource "aws_eks_node_group" "sample" {
  cluster_name    = aws_eks_cluster.sample.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  version         = "1.31"

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  instance_types = ["t3.medium"]
}
