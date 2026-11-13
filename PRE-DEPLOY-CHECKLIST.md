# Pre-Deploy Checklist: EKS 1.24 ⇒ 1.31

> ⚠️ **IMPORTANT:** AWS recommends upgrading one minor version at a time, without skipping versions. The code moves from
> 1.24 to 1.31 in one step only because EKS no longer offers 1.25 to 1.30, and 1.24 clusters past end of extended
> support are upgraded automatically. 1.31 is the version this step reconciles the code to. Before you apply:
> confirm the live cluster version, test in a Dev/non-prod environment first, and treat this checklist as approximate.
> API removals across 1.25 to 1.31 add up, and some workload breaks may only show up on the live cluster.

## Summary of this transformation

**What changed**

| File:line | Change | Why |
|---|---|---|
| `main.tf:21` (`aws_eks_cluster.sample`) | `version` `"1.24"` → `"1.31"` | 1.24 is past end of extended support; 1.31 is the oldest version EKS offers |
| `main.tf:33` (`aws_eks_node_group.sample`) | `version` `"1.24"` → `"1.31"` | Keep the kubelet inside the supported skew of the control plane |
| `main.tf:16-17` | Comment updated to describe the new pin | The old comment ("intentionally outdated") was no longer accurate |
| `README.md` | 1.24 statements updated to 1.31 and the next-hop guidance | Docs matched the old pin |

**What was NOT changed** (no destroy/recreate expected)

Resource names and identifiers (`sample`, `node_group_name`), variables, outputs, the AWS provider constraint
(`~> 5.0`, already sufficient) and `required_version` are unchanged. No `ami_type` was added, because AL2 is still valid
at 1.31. The AL2023 move belongs to the 1.32 → 1.33 hop.

**Flagged for you** (detected, not auto-fixed)

- Confirm the live control-plane version (`aws eks describe-cluster`). If it is above 1.31, set both `version` fields
  to the live value.
- Managed add-ons (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver) are not in this Terraform. Upgrade them for 1.31,
  then again on every hop. CoreDNS uses its own `v1.11.x` line.
- Kubernetes APIs removed in 1.25 to 1.29 (PodSecurityPolicy, `batch/v1beta1`, `policy/v1beta1`, `autoscaling/v2beta1`
  and `v2beta2`, flowcontrol `v1beta1` and `v1beta2`, `storage.k8s.io/v1beta1` CSIStorageCapacity). There are no
  manifests in this repo, so scan the cluster with `kubent` or `pluto`.
- The node group has no `ami_type`, so it uses the AL2 default. It must move to AL2023 or Bottlerocket at the 1.33 hop.
  Container images must meet the cgroup v2 runtime minimums by then.
- 1.31 is in extended support (surcharge; ends around 2026-11-26, to be confirmed). Continue to 1.32 and onward to 1.37
  promptly.
- 1.37 is newer than the cached breaking-change data, so check its release notes.

**How it was verified**

| # | Criterion | State |
|---|---|---|
| 1 | Cluster version fields equal the target (1.31); no `"1.24"` literal left in `*.tf` | PASS |
| 2 | AMI migrated | N/A (target < 1.33) |
| 3 | Add-on versions | N/A (no add-ons managed in the repo) |
| 4 | Karpenter | N/A (not present) |
| 5 | cluster-autoscaler tag | N/A (not present) |
| 6 | Guardrails held (names, identifiers, provider pin unchanged) | PASS (`git diff`) |
| 7 | `UPGRADE-STEPS.md` emitted | PASS |
| 8 | Idempotent; files parse | PASS (a re-run makes no further edits; `terraform fmt -check` clean) |
| 8a | Provider meets the minimum | N/A (`~> 5.0` already sufficient; resolved 5.100.0) |
| 9 | `terraform init -backend=false && terraform validate` | PASS (Terraform 1.9.8, AWS provider 5.100.0) |
| 10 | Live add-on, cluster and plan checks | DEFERRED (no EKS read permissions here). Run the `describe-addon-versions` loop in `UPGRADE-STEPS.md` and `terraform plan` |

**Deliverables**

- `UPGRADE-STEPS.md`: ordered apply runbook for the reconciliation step and every later hop to 1.37.
- `eks-upgrade-analysis-and-roadmap.html`: per-hop analysis by layer, plus the Production Roadmap.
- `PRE-DEPLOY-CHECKLIST.md`: this file.

**Next steps to production**

Follow `UPGRADE-STEPS.md` together with the Production Roadmap, one hop at a time. It covers the control-plane
upgrade, the add-ons AWS does not upgrade for you, the node roll, and the workload checks for each hop.

## Pre-deployment checklist

- [ ] Live control-plane version confirmed; `main.tf` matches it (1.31, or the higher live value)
- [ ] `kubent` / `pluto` show no removed APIs for 1.31
- [ ] PodDisruptionBudgets allow at least one eviction; replicas are spread across AZs
- [ ] Backup taken
- [ ] `terraform plan` shows only in-place updates (no destroy/recreate of `aws_eks_cluster.sample` / `aws_eks_node_group.sample`)
- [ ] Validated in Dev/non-prod before higher environments
- [ ] After the apply: add-ons upgraded for 1.31; nodes Ready at 1.31; smoke tests pass
- [ ] Hop 1.31 → 1.32 scheduled (re-run the transformation)
