# EKS Upgrade Readiness Assessment — 1.24 → 1.31 (Hop 1)

**TRANSFORMATION COMPLETE — live/CLI checks DEFERRED (no EKS read access in this environment)**

Repository: `eks-outdated-version-sample` · Scan date: 2026-11-13 · IaC framework: Terraform (native
`aws_eks_cluster` / `aws_eks_node_group`, `main.tf`) · Data source: DOCS-ONLY.

- Current EKS version in code: `1.24` (`main.tf:20`, `main.tf:32`) — past end of extended support since 2025-01-31.
- Target for this run: `1.31`. Versions 1.25–1.30 are also past end of extended support, so EKS has
  auto-upgraded such clusters to 1.31, the oldest version it still offers. This run brings the code in
  line with that state; later hops (1.31 → … → 1.37) are left for later runs, one minor at a time.

## Summary of this transformation

**What changed**

| File:line | Change | Why |
|---|---|---|
| `main.tf:22` | `aws_eks_cluster.sample` `version` `"1.24"` → `"1.31"` | 1.24–1.30 can no longer be targeted; 1.31 is the oldest version EKS offers |
| `main.tf:34` | `aws_eks_node_group.sample` `version` `"1.24"` → `"1.31"` | Node group must match the control plane (kubelet skew is at most 3 minors) |
| `main.tf:16-18` | Comment "Intentionally outdated…" → upgrade-history comment | The old comment no longer described the code |
| `README.md` | Pinned-version text 1.24 → 1.31, plus a note to confirm the live version | Documentation matched the old pin |

New files: `eks-upgrade-analysis-and-roadmap.html` (analysis + production roadmap),
`UPGRADE-STEPS.md` (apply runbook), this assessment.

**What was NOT changed** (no destroy/recreate)

Resource names and identifiers (`aws_eks_cluster.sample`, `aws_eks_node_group.sample`,
`node_group_name`), variables, outputs, the AWS provider constraint (`~> 5.0`, which already supports
1.31 and AL2023), and `required_version` are unchanged. The repo has no IAM policy documents or module
source pins.

**Flagged for you** (detected, not auto-rewritten)

- 🔴 **Confirm the live control-plane version** before applying (`aws eks describe-cluster`). If it is
  not 1.31, set the code to the live value; never apply a lower version.
- 🔴 **Add-ons are not managed in this repo.** vpc-cni, coredns and kube-proxy on a cluster that was
  created at 1.24 are probably still 1.24-era — upgrade them to 1.31-compatible versions (CoreDNS uses
  its own `v1.11.x` line). Consider managing them with `aws_eks_addon` resources.
- 🔴 **Node group skew:** if the live node group is still at 1.24, roll it to 1.31 right after the
  control plane.
- 🔴 **Removed Kubernetes APIs (1.25/1.26/1.27/1.29):** no manifests in this repo; scan deployed
  workloads with `kubent`/`pluto` (CronJob `batch/v1beta1`, PDB `policy/v1beta1`, PodSecurityPolicy,
  HPA `autoscaling/v2beta1|v2beta2`, EndpointSlice/Event v1beta1, RuntimeClass v1beta1,
  CSIStorageCapacity v1beta1, flowcontrol v1beta1/v1beta2).
- ⚠️ **1.31 is in extended support** (surcharge) and its extended support ends around 2026-11-26 (verify).
  Plan the 1.31 → 1.32 hop promptly; the AL2 → AL2023 node move comes at 1.33.
- ⚠️ No `ami_type` is set on the node group (AL2 default). Not a problem at 1.31; it must be set to
  `AL2023_x86_64_STANDARD` at the 1.33 hop.

**How it was verified**

| # | Criterion | State | Evidence |
|---|---|---|---|
| 1 | Cluster version bumped | PASS | Both `version` fields = `1.31`; `grep -n '1\.24' *.tf` matches only the history comment |
| 2 | AMI migrated (TO_VER ≥ 1.33) | N/A | Target 1.31 < 1.33; no `AL2_*` literals in the repo |
| 3 | Add-on versions | N/A | No add-on resources in the repo (flagged above) |
| 4 | Karpenter compatible | N/A | No Karpenter |
| 5 | cluster-autoscaler tag | N/A | No cluster-autoscaler |
| 6 | Never-touch guardrails held | PASS | Diff only touches `version` lines, one comment and the README |
| 7 | Apply-runbook emitted | PASS | `UPGRADE-STEPS.md` at repo root |
| 8 | Idempotent + static parse | PASS | Re-run finds `version = "1.31"` already set → no change; `terraform fmt -check` clean |
| 8a | Provider meets target minimum | N/A | `~> 5.0` already meets the minimum; no `aws_subnet_ids` |
| 8c | End-state deliverables | N/A | Default single-hop mode |
| 9 | Format validator | PASS (plan DEFERRED) | `terraform init -backend=false && terraform validate` → Success (hashicorp/aws 5.100.0). `terraform plan` needs AWS credentials and state |
| 10 | Add-on versions vs live API | DEFERRED | `eks:DescribeAddonVersions` denied. Finish with: `aws eks describe-addon-versions --kubernetes-version 1.31 --addon-name {vpc-cni,coredns,kube-proxy} --query 'addons[0].addonVersions[0].addonVersion' --output text` |

Not applicable: AL2 → AL2023 node AMI (belongs to the 1.33 hop), container base images for cgroup v2
(no Dockerfiles; belongs to the 1.33 hop), Karpenter, cluster-autoscaler, EKS managed add-on pins,
CloudFormation / CDK / eksctl (repo is Terraform only), IaC provider upgrade (already sufficient).

**Deliverables**

- `UPGRADE-STEPS.md` — the ordered runbook for this hop (control plane → add-ons → data plane), the
  7-day rollback note, and the list of next hops.
- `eks-upgrade-analysis-and-roadmap.html` — what breaks per hop (IaC, cluster, add-ons, nodes,
  workloads) from 1.24 to 1.37, and the Production Roadmap.
- `UPGRADE-ASSESSMENT.md` — this file.

**Next — how to take this to production**

Follow `UPGRADE-STEPS.md` with the Production Roadmap, one hop at a time: confirm the live version,
upgrade the control plane, upgrade the add-ons AWS does not upgrade for you, roll the node group, and
check workloads. Start in Dev, then promote to UAT and Production. Then re-run the transformation for
1.31 → 1.32.
