# pez-k8s-apps

Workloads for the pez-london and pez-copenhagen clusters, reconciled by
ArgoCD from the top-level [`pez-k8s`](https://github.com/RWejlgaard/pez-k8s)
GitOps repo. Each cluster runs its own independent, self-managing ArgoCD
instance (there is no hub cluster), so every `Application`'s
`destination.server` is always the local `https://kubernetes.default.svc`.

## Layout

- `apps/<name>/base/` holds a workload's manifests, once, cluster-agnostic.
- `clusters/<cluster>/appset.yaml` is an ArgoCD `ApplicationSet` that
  generates one `Application` per value file matching
  `clusters/<cluster>/apps/*.yaml`. Which workloads run on a cluster is
  controlled purely by which value files exist in that cluster's directory,
  so clusters can run different app sets.
- `clusters/<cluster>/apps/<name>.yaml` is a small value file:

  ```yaml
  app: podinfo                     # Application name and apps/<app>/base path
  hostname: podinfo.lon.pez.sh     # HTTPRoute hostname, patched in by the appset
  # sourcePath: apps/podinfo/overlays/pez-london   # optional path override
  ```

- Each cluster's `pez-k8s/clusters/<cluster>/apps.yaml` points at
  `clusters/<cluster>` here (non-recursive directory sync, so it applies
  `appset.yaml` and ignores the value files under `apps/`).

The per-cluster hostname (the only routine per-cluster difference) is
patched into the base `HTTPRoute` by the ApplicationSet's inline kustomize
patch, so a typical workload needs no overlay directories at all. A workload
that genuinely diverges per cluster (see secrets below) sets `sourcePath` to
a real overlay, e.g. `apps/<name>/overlays/<cluster>/`, with a
`kustomization.yaml` referencing `../../base` plus its patches; the inline
hostname patch still applies on top.

## Workload conventions

A workload's `base/` contains a dedicated namespace (ambient mesh-joined),
ServiceAccount, Deployment, Service, and a Gateway API `HTTPRoute` attached
to the shared `istio-system/shared-gateway` (TLS terminated at Caddy, which
forwards to the ingress gateway over Tailscale). A `PodDisruptionBudget` is
added whenever a workload runs more than one replica.

Pods run hardened by default: non-root uid 65532, all capabilities dropped,
read-only root filesystem, no mounted SA token (the SA is only a mesh
identity, ztunnel gets certs from istiod). Images that need root or a
writable rootfs (e.g. `echo`, `pez-sh`) opt out explicitly in their
Deployment's `securityContext`.

| App | pez-london | pez-copenhagen | Notes |
|-----|-----------|-----------------|-------|
| podinfo | podinfo.lon.pez.sh | podinfo.cph.pez.sh | stefanprodan/podinfo demo app |
| echo | echo.lon.pez.sh | echo.cph.pez.sh | ealen/echo-server request echo |
| pez-sh | pez-sh.lon.pez.sh | pez-sh.cph.pez.sh | rwejlgaard/pez.sh personal site |
| pez-solutions | pez-solutions.lon.pez.sh | pez-solutions.cph.pez.sh | rwejlgaard/pez.solutions homelab site |

Workloads run on Karpenter-provisioned nodes (`nodeSelector: karpenter.sh/nodepool=default`).

## Adding a workload

Write the plain manifests under `apps/<name>/base/` (copy an existing app as
a template), then add a `clusters/<cluster>/apps/<name>.yaml` value file for
each cluster it should run on. That's it, the ApplicationSet picks it up.

## Adding a workload to only one cluster

Only create the value file under that cluster's `clusters/<cluster>/apps/`.
Nothing else changes.

## Adding a secret

Secrets are sealed with the [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
controller running in `pez-k8s` (see that repo's README for how to seal a
value). Because each cluster's controller has its own independent keypair, a
`SealedSecret` encrypted for one cluster can't be decrypted by another, so
unlike the rest of a workload's manifests, **a `SealedSecret` always goes in
`apps/<name>/overlays/<cluster>/`, never in `base/`**, even if the same
logical secret exists on every cluster the workload runs on. Create the
overlay (`kustomization.yaml` referencing `../../base` plus the
`SealedSecret`), and point the workload's value file at it with
`sourcePath: apps/<name>/overlays/<cluster>`. The `Secret` it decrypts to
still gets referenced from `base/` (e.g. via `envFrom`/`secretKeyRef`) since
only the name/namespace has to match, not the manifest's location.

## Adding a cluster

Create `clusters/<new-cluster>/appset.yaml` (copy an existing one and change
the generator's `files` path), add a value file per workload under
`clusters/<new-cluster>/apps/`, and add a matching
`pez-k8s/clusters/<new-cluster>/apps.yaml` pointing at
`clusters/<new-cluster>` here.
