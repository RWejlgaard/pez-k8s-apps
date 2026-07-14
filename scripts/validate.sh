#!/usr/bin/env bash

# Validate every manifest and kustomize overlay in this repo against its JSON
# schema, mirroring what ArgoCD's repo-server does before it applies. Same
# pattern as pez-k8s's scripts/validate.sh.
#
# Two categories of manifest here: workload bases under apps/<name>/base/
# (and any per-cluster overlays), each owning a kustomization.yaml -
# `kustomize build` + kubeconform, one pass per kustomization; and the
# per-cluster clusters/<cluster>/appset.yaml, applied by ArgoCD directly with
# no kustomization wrapping it, so kubeconform runs on those loose instead.
#
# clusters/<cluster>/apps/*.yaml are deliberately NOT validated: they're
# plain ApplicationSet generator value files (app/hostname/sourcePath), not
# Kubernetes manifests, and have no apiVersion/kind for kubeconform to check.
#
# Schemas: the Kubernetes defaults and the community CRDs-catalog (Gateway
# API's HTTPRoute, ArgoCD's ApplicationSet). Anything still unknown is
# skipped via -ignore-missing-schemas rather than failing the build.
#
# Requires: kustomize, kubeconform, curl, tar.

set -o errexit
set -o pipefail

# mirror kustomize-controller build options
kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
kustomize_config="kustomization.yaml"

# Skip Secrets: a workload's SealedSecret decrypts to one, but nothing here
# ever commits a raw Secret manifest.
kubeconform_flags=(
  "-strict"
  "-ignore-missing-schemas"
  "-skip=Secret"
  "-schema-location" "default"
  "-schema-location" "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
  "-verbose"
)

echo "INFO - Validating kustomizations"
find . -type f -name "${kustomize_config}" -print0 | while IFS= read -r -d $'\0' file; do
  dir="${file%${kustomize_config}}"
  echo "INFO - Validating kustomization ${dir}"
  kustomize build "${dir}" "${kustomize_flags[@]}" | kubeconform "${kubeconform_flags[@]}"
done

echo "INFO - Validating loose ApplicationSets"
find clusters -type f -name "appset.yaml" -print0 | while IFS= read -r -d $'\0' file; do
  echo "INFO - Validating ${file}"
  kubeconform "${kubeconform_flags[@]}" "${file}"
done

echo "INFO - All manifests valid"
