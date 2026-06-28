# pez-k8s-apps

Workloads for the pez-k8s cluster, reconciled by Flux from the top-level
[`pez-k8s`](https://github.com/RWejlgaard/pez-k8s) GitOps repo.

Each app is a single `Workload` custom resource in `apps/workloads/`, living in
the `workloads` namespace. The `workload` kro `ResourceGraphDefinition` (defined
in the `pez-k8s` infra repo) fans each one out into its own per-app namespace
with a Deployment, Service, an optional PodDisruptionBudget, and a Gateway API
`HTTPRoute` on `<name>.k8s.pez.sh`, attached to the shared
`istio-system/shared-gateway` (TLS terminated at Caddy, which forwards to the
ingress gateway over Tailscale).

A minimal app is just an image and a port:

```yaml
apiVersion: kro.run/v1alpha1
kind: Workload
metadata:
  name: echo
  namespace: workloads
spec:
  image: ealen/echo-server:0.9.2
  port: 80
```

Defaults: `replicas: 1`, probes on `/`, host `<name>.k8s.pez.sh`, and modest
CPU/memory requests/limits. A PodDisruptionBudget and topology spread kick in
automatically when `replicas > 1`. See `Workload` spec fields in the RGD
(`infrastructure/kro/workload-rgd.yaml`) for the full set of overrides.

| App | Host | Notes |
|-----|------|-------|
| podinfo | podinfo.k8s.pez.sh | stefanprodan/podinfo demo app |
| echo | echo.k8s.pez.sh | ealen/echo-server request echo |
| pez-sh | pez-sh.k8s.pez.sh | rwejlgaard/pez.sh personal site |

Workloads run on Karpenter-provisioned nodes (`nodeSelector: karpenter.sh/nodepool=default`).
