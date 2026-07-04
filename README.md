# pez-k8s-apps

Workloads for the pez-k8s cluster, reconciled by ArgoCD from the top-level
[`pez-k8s`](https://github.com/RWejlgaard/pez-k8s) GitOps repo.

This repo is itself an "app of apps": the top-level `kustomization.yaml`
lists one ArgoCD `Application` per workload (`apps/<name>/application.yaml`),
each syncing that workload's own plain-manifest directory
(`apps/<name>/manifests/`) independently.

A workload's manifests are plain Kubernetes YAML — a dedicated namespace
(ambient mesh-joined), ServiceAccount, Deployment, Service, and a Gateway API
`HTTPRoute` on `<name>.k8s.pez.sh` attached to the shared
`istio-system/shared-gateway` (TLS terminated at Caddy, which forwards to the
ingress gateway over Tailscale). A `PodDisruptionBudget` is added whenever a
workload runs more than one replica.

Pods run hardened by default: non-root uid 65532, all capabilities dropped,
read-only root filesystem, no mounted SA token (the SA is only a mesh
identity — ztunnel gets certs from istiod). Images that need root or a
writable rootfs (e.g. `echo`, `pez-sh`) opt out explicitly in their
Deployment's `securityContext`.

| App | Host | Notes |
|-----|------|-------|
| podinfo | podinfo.k8s.pez.sh | stefanprodan/podinfo demo app |
| echo | echo.k8s.pez.sh | ealen/echo-server request echo |
| pez-sh | pez-sh.k8s.pez.sh | rwejlgaard/pez.sh personal site |

Workloads run on Karpenter-provisioned nodes (`nodeSelector: karpenter.sh/nodepool=default`).

## Adding a workload

Copy an existing `apps/<name>/` directory as a template: add an
`application.yaml` (ArgoCD `Application` pointed at
`apps/<name>/manifests`), write the plain manifests, and list the new
`application.yaml` in the top-level `kustomization.yaml`.
