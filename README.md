# Outdated EKS version sample

This repository contains Terraform for an Amazon EKS cluster and a small managed node group. It was originally pinned to the obsolete Kubernetes version `1.24` (past end of extended support since 2025-01-31) for scanner/compliance demonstrations and is now pinned to `1.31`, the oldest version Amazon EKS still offers. It is not intended for production use.

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

The configuration pins both the control plane and node group to `1.31`. 1.31 is in extended support, so continue upgrading one minor version at a time toward `1.37` as described in `UPGRADE-STEPS.md`. Do not use this sample for production.
