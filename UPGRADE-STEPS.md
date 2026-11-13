# EKS Upgrade Runbook — 1.24 (code) → 1.31

This runbook applies the Terraform change in this branch to a live cluster. **Nothing here has
been run for you** — the transformation only changed code.

- **Why 1.31 and not 1.25:** Kubernetes 1.24–1.30 are past end of extended support on Amazon EKS
  and can no longer be targeted. EKS automatically upgrades clusters on those versions to the oldest
  offered version, which is **1.31**. This hop reconciles the code with that state.
- **Order for every hop:** control plane → add-ons → data plane (node group). One minor at a time.
- **Rollback:** a control-plane upgrade can be rolled back within **7 days**; after the node roll it
  is effectively permanent. Back up workload manifests before you start.
- **Test in a Dev/non-prod environment first**, then promote Dev → UAT/Staging → Production.
- See `eks-upgrade-analysis-and-roadmap.html` (Production Roadmap tab) for the full playbook.

Placeholders: `CLUSTER=outdated-eks-sample` (default `var.cluster_name`), `REGION=us-east-1`,
`NODEGROUP=${CLUSTER}-nodes`.

## Hop 1 — reconcile to 1.31

### 0. Confirm the live state (read-only)

```bash
aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query cluster.version --output text
aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" --region "$REGION" \
  --query 'nodegroup.{version:version,amiType:amiType,release:releaseVersion}'
aws eks list-addons --cluster-name "$CLUSTER" --region "$REGION"
aws eks list-insights --cluster-name "$CLUSTER" --region "$REGION" --filter categories=UPGRADE_READINESS
kubectl get nodes -o wide
```

- If the control plane reports a version **other than 1.31**, change `version` in `main.tf` (cluster
  and node group) to that value before applying — never apply a lower version than the live one.
- If no cluster exists yet, `terraform apply` simply creates it at 1.31.
- Scan workloads for APIs removed in 1.25, 1.26, 1.27 and 1.29 (`kubent`, `pluto`) and fix them
  first (see the analysis report, Hop 1 → App/Workload).

### 1. Terraform plan (confirm in-place)

```bash
terraform init -upgrade
terraform validate
terraform plan -out=hop1.tfplan
```

Expected: `aws_eks_cluster.sample` and `aws_eks_node_group.sample` show **update in-place**
(`version`). If either shows **must be replaced / destroy**, stop and investigate.

### 2. Control plane

```bash
terraform apply -target=aws_eks_cluster.sample   # control plane only; review the prompt before confirming
```

If the cluster is already on 1.31 this is a no-op for the control plane.

### 3. Add-ons (not managed by this repo — AWS does not upgrade them for you)

Resolve the 1.31-compatible versions, then upgrade each add-on (CoreDNS has its own version line,
`v1.11.x`, NOT `v1.31.x`; kube-proxy tracks the cluster minor):

```bash
for a in vpc-cni coredns kube-proxy; do
  aws eks describe-addon-versions --kubernetes-version 1.31 --addon-name "$a" \
    --query 'addons[0].addonVersions[0].addonVersion' --output text
done
# Managed add-on:
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy --addon-version <v1.31.x-eksbuild.N> \
  --resolve-conflicts PRESERVE
# Self-managed (default) add-ons: create them as managed add-ons, or update the DaemonSet/Deployment images.
```

vpc-cni should be upgraded one minor at a time.

### 4. Data plane (managed node group)

```bash
terraform apply    # rolls aws_eks_node_group.sample to 1.31 (nodes replaced, PDBs respected)
kubectl get nodes   # all nodes Ready at v1.31.x
```

Nodes left at 1.24 behind a 1.31 control plane are outside the supported kubelet skew (n-3), so do
this step right after the control plane.

### 5. Validation gate

- Control plane and nodes report 1.31; all nodes `Ready`.
- No `OOMKilled` / `CrashLoopBackOff`; CoreDNS resolving; CNI assigning IPs.
- No `PodEvictionFailure` during the node roll; application smoke tests pass.

## Next hops (re-run the transformation once per hop)

1.31 extended support ends around **2026-11-26** (verify), so continue promptly:

| Hop | Key items |
| --- | --- |
| 1.31 → 1.32 | `flowcontrol.apiserver.k8s.io/v1beta3` removed; last version with AL2 AMIs |
| 1.32 → 1.33 | Node group must move to `ami_type = "AL2023_x86_64_STANDARD"`; cgroup v2 runtime minimums |
| 1.33 → 1.34 | containerd 2.1; AppArmor deprecated |
| 1.34 → 1.35 | cgroup v1 removed; last containerd 1.x release |
| 1.35 → 1.36 | kube-proxy IPVS removed; `gitRepo` volumes disabled |
| 1.36 → 1.37 | Verify against the 1.37 release notes (newer than cached analysis) |
