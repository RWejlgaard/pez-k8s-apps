# pez-k8s-apps

Workloads for the pez-k8s cluster, reconciled by Flux from the top-level
[`pez-k8s`](https://github.com/RWejlgaard/pez-k8s) GitOps repo.

Each app lives under `apps/<name>/` and is exposed via an Istio `Gateway` +
`VirtualService` on `<name>.k8s.pez.sh` (TLS terminated at Caddy, which forwards
to the ingress gateway over Tailscale).

| App | Host | Notes |
|-----|------|-------|
| podinfo | podinfo.k8s.pez.sh | stefanprodan/podinfo demo app |
| echo | echo.k8s.pez.sh | ealen/echo-server request echo |
| pez-sh | pez-sh.k8s.pez.sh | rwejlgaard/pez.sh personal site |

Workloads run on Karpenter-provisioned nodes (`nodeSelector: karpenter.sh/nodepool=default`).
