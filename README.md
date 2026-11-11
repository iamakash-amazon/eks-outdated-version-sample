# Outdated EKS version sample

This repository contains Terraform for an intentionally outdated Amazon EKS Kubernetes version (`1.24`) and a small managed node group. It is intended for scanner/compliance demonstrations, not production use. EKS 1.24 is past standard support and may no longer be accepted by AWS for new clusters.

## Requirements

- Terraform 1.5 or later
- AWS credentials with permissions to create EKS resources
- Existing EKS cluster and node IAM roles, plus at least two suitable subnet IDs

Set the required values in `terraform.tfvars` (do not commit credentials):

```hcl
cluster_role_arn = "arn:aws:iam::123456789012:role/eks-cluster-role"
node_role_arn    = "arn:aws:iam::123456789012:role/eks-node-role"
subnet_ids       = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789a"]
```

The manifest deliberately pins both the control plane and node group to `1.24` so infrastructure scanners can detect the obsolete version. AWS may reject a deployment because this version is unsupported. Do not use this sample for production.
