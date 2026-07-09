# pez-k8s-apps

Workloads for the pez-london and pez-copenhagen clusters, reconciled by
ArgoCD from the top-level [`pez-k8s`](https://github.com/RWejlgaard/pez-k8s)
GitOps repo. Each cluster runs its own independent, self-managing ArgoCD
instance — there is no hub cluster — so every `Application`'s
`destination.server` is always the local `https://kubernetes.default.svc`.

This repo is itself an "app of apps", two levels deep:

- `clusters/<cluster>/kustomization.yaml` lists one ArgoCD `Application` per
  workload deployed to that cluster (`clusters/<cluster>/<name>-application.yaml`,
  each pointed at that workload's `apps/<name>/overlays/<cluster>`). These
  live under `clusters/<cluster>/` rather than next to the overlay they
  point at because ArgoCD's kustomize security setting only allows loading
  a resource from outside the build root when it's a directory with its own
  `kustomization.yaml` — a loose file like `application.yaml` must stay
  local to the kustomization that references it.
- Each cluster's `pez-k8s/clusters/<cluster>/apps.yaml` points at
  `clusters/<cluster>` here.

A workload's manifests live once, in `apps/<name>/base/` — a dedicated
namespace (ambient mesh-joined), ServiceAccount, Deployment, Service, and a
Gateway API `HTTPRoute` attached to the shared `istio-system/shared-gateway`
(TLS terminated at Caddy, which forwards to the ingress gateway over
Tailscale). A `PodDisruptionBudget` is added whenever a workload runs more
than one replica. Per-cluster differences are layered on in
`apps/<name>/overlays/<cluster>/`, currently just a patch swapping the
`HTTPRoute` hostname's cluster suffix (`.lon.pez.sh` / `.cph.pez.sh`).

Pods run hardened by default: non-root uid 65532, all capabilities dropped,
read-only root filesystem, no mounted SA token (the SA is only a mesh
identity — ztunnel gets certs from istiod). Images that need root or a
writable rootfs (e.g. `echo`, `pez-sh`) opt out explicitly in their
Deployment's `securityContext`.

| App | pez-london | pez-copenhagen | Notes |
|-----|-----------|-----------------|-------|
| podinfo | podinfo.lon.pez.sh | podinfo.cph.pez.sh | stefanprodan/podinfo demo app |
| echo | echo.lon.pez.sh | echo.cph.pez.sh | ealen/echo-server request echo |
| pez-sh | pez-sh.lon.pez.sh | pez-sh.cph.pez.sh | rwejlgaard/pez.sh personal site |

Workloads run on Karpenter-provisioned nodes (`nodeSelector: karpenter.sh/nodepool=default`).

## Adding a workload

Copy an existing `apps/<name>/` directory as a template: write the plain
manifests under `base/`, add an `overlays/<cluster>/` per cluster it should
run on (`kustomization.yaml` referencing `../../base`, plus any patches —
e.g. `httproute-patch.yaml` for the hostname), then add a
`clusters/<cluster>/<name>-application.yaml` ArgoCD `Application` pointed at
`apps/<name>/overlays/<cluster>` and list it in that cluster's
`clusters/<cluster>/kustomization.yaml`.

## Adding a workload to only one cluster

Skip creating an `overlays/<cluster>/` and the corresponding
`clusters/<cluster>/<name>-application.yaml` for any cluster the workload
shouldn't run on — nothing else changes.

## Adding a cluster

Create `clusters/<new-cluster>/kustomization.yaml`, add an
`overlays/<new-cluster>/` under each `apps/<name>/` that should run there,
and add + list a `clusters/<new-cluster>/<name>-application.yaml` per
workload. Then add a matching `pez-k8s/clusters/<new-cluster>/apps.yaml`
pointing at `clusters/<new-cluster>` here.
