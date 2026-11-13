# Outdated EKS version sample

This repository contains Terraform for an Amazon EKS cluster and a small managed node group. It was originally pinned to the obsolete Kubernetes version `1.24` for scanner/compliance demonstrations and has been upgraded to `1.31`, the oldest version Amazon EKS still offers (1.24-1.30 are past end of extended support, and EKS auto-upgrades clusters on those versions). `1.31` is itself in extended support, so keep upgrading one minor version at a time (see `UPGRADE-STEPS.md`). It is not intended for production use.

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

The manifest pins both the control plane and node group to `1.31`. Before applying, confirm the live cluster version with `aws eks describe-cluster --name <cluster> --query cluster.version`; if EKS has already moved the cluster to a newer version, set the code to that version instead. Do not use this sample for production.
