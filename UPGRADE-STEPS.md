# EKS Upgrade Runbook: 1.24 ⇒ 1.31, then one minor at a time to 1.37

This runbook is documentation only. The transformation changed the Terraform code and did not run any of these
commands against a cluster. Run them yourself, with your own credentials, in Dev first, then UAT/Staging, then Production.

- **Order for every hop:** control plane → add-ons → data plane (node group) → validate → promote.
- **One minor at a time.** After the reconciliation step, never skip a minor version.
- **Rollback:** EKS control planes cannot be downgraded. Take a backup (for example Velero, or exported manifests)
  before each hop. Assume a hop is permanent once the node group has rolled.
- Full analysis and the Production Roadmap: `eks-upgrade-analysis-and-roadmap.html`.

## Step 0: reconcile the code to 1.31 (this change)

1.24 has been past end of extended support since 2025-01-31, and Amazon EKS automatically upgrades clusters in that
state. 1.25 to 1.30 are no longer offered, so the code now pins `1.31`, the oldest version EKS still offers.

```bash
# 0.1 Confirm the live control-plane and node-group versions
aws eks describe-cluster --name outdated-eks-sample --region us-east-1 --query cluster.version --output text
aws eks describe-nodegroup --cluster-name outdated-eks-sample --nodegroup-name outdated-eks-sample-nodes \
  --region us-east-1 --query 'nodegroup.[version,amiType,releaseVersion]' --output text
```

- If the live control plane is **already above 1.31**, change both `version` fields in `main.tf` to the live value
  before you apply. EKS cannot downgrade.
- If the control plane is still **1.24**, the apply asks EKS to move it to 1.31, and EKS may reject that because
  1.25 to 1.30 are no longer offered. In that case, wait for the automatic upgrade or contact AWS Support, then
  re-run the plan.

```bash
# 0.2 Check for removed APIs (1.25: PSP, batch/v1beta1, policy/v1beta1, autoscaling/v2beta1, ...;
#     1.26: flowcontrol v1beta1, autoscaling/v2beta2; 1.27: storage v1beta1 CSIStorageCapacity; 1.29: flowcontrol v1beta2)
kubent            # or: pluto detect-all-in-cluster

# 0.3 Plan and apply
terraform init -upgrade
terraform validate
terraform plan    # expect: aws_eks_cluster.sample no change (already auto-upgraded) or in-place version update;
                  #         aws_eks_node_group.sample in-place update version 1.24 -> 1.31 (NOT destroy/recreate)
terraform apply
```

- The node group update is a rolling replacement that respects PodDisruptionBudgets. A 1.24 kubelet is outside the
  n-3 skew allowed by a 1.31 control plane, so do this right away.
- **Add-ons:** they are not managed in this Terraform, and EKS does not upgrade them for you. After the apply:

```bash
for a in vpc-cni coredns kube-proxy aws-ebs-csi-driver; do
  echo "$a: $(aws eks describe-addon-versions --kubernetes-version 1.31 --addon-name $a \
      --query 'addons[0].addonVersions[0].addonVersion' --output text)"
done
aws eks list-addons --cluster-name outdated-eks-sample --region us-east-1
aws eks update-addon --cluster-name outdated-eks-sample --addon-name <name> --addon-version <version> \
  --resolve-conflicts PRESERVE
```

  CoreDNS has its own version line (`v1.11.x`), not `v1.31.x`. kube-proxy follows the cluster minor (`v1.31.x-eksbuild.N`).
  Install `aws-ebs-csi-driver` if any workload uses EBS volumes. The in-tree EBS plugin was removed in 1.27.
- **Validate:** see the gate below.

## Hop 1: 1.31 → 1.32 (1.31 extended support ends around 2026-11-26, so start soon)

1. Re-run the transformation (both `version` fields `1.31` → `1.32`).
2. Migrate `flowcontrol.apiserver.k8s.io/v1beta3` objects to `v1` (removed in 1.32). Check RBAC that relies on
   `system:unauthenticated`.
3. `terraform plan` (in-place) → `terraform apply` (control plane first, then the node group).
4. Upgrade the add-ons to the `--kubernetes-version 1.32` targets. Validate.

## Hop 2: 1.32 → 1.33 (Amazon Linux 2 boundary)

1. Re-run the transformation. This hop also sets `ami_type = "AL2023_x86_64_STANDARD"` on `aws_eks_node_group.sample`,
   because 1.33 has no AL2 AMI. Review the plan closely: changing `ami_type` can replace the node group.
2. Before the apply, confirm that workload images meet the cgroup v2 minimums (JDK ≥ 8u372 / 11.0.16, Node.js ≥ 16.19,
   .NET ≥ 6.0.2). Plan to move consumers of the deprecated Endpoints API to EndpointSlices.
3. Apply, upgrade the add-ons for 1.33, validate.

## Hops 3–6: 1.33 → 1.34 → 1.35 → 1.36 → 1.37

Each hop: re-run the transformation → `terraform plan`/`apply` → add-ons for that version → node roll → validate.

- **1.34:** containerd 2.1; AppArmor deprecated.
- **1.35:** cgroup v1 removed; `--pod-infra-container-image` removed; kube-proxy IPVS deprecated.
- **1.36:** `gitRepo` volumes disabled; strict IP/CIDR validation; IPVS removed.
- **1.37:** newer than the cached breaking-change data. Check the official 1.37 release notes and the Kubernetes
  deprecation guide before this hop.

## Validation gate (every hop, every environment)

```bash
aws eks describe-cluster --name outdated-eks-sample --query cluster.version --output text
kubectl get nodes -o wide                                   # all Ready, kubelet at target
kubectl get pods -A | grep -Ev 'Running|Completed'           # no CrashLoopBackOff / OOMKilled
kubectl -n kube-system get ds aws-node kube-proxy; kubectl -n kube-system get deploy coredns
```

Then run your application smoke tests, and promote Dev → UAT/Staging → Production.
