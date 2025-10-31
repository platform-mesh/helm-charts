#!/bin/zsh


# Deploy marketplace-ui
unset KUBECONFIG
kubectx kind-platform-mesh

# Get GitHub token and create image pull secret
GH_TOKEN=$(gh auth token)
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=$(gh api user --jq '.login') \
  --docker-password=$GH_TOKEN \
  --docker-email=$(gh api user --jq '.email // "noreply@github.com"') \
  -n platform-mesh-system \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade -i marketplace-ui -n platform-mesh-system ../helm-charts-priv/charts/marketplace-ui \
  --set imagePullSecret=ghcr-pull-secret


export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://kcp.api.portal.dev.local:8443/clusters/root"
kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://kcp.api.portal.dev.local:8443/clusters/root:providers"
kubectl create-workspace infra-provider --type=root:provider --ignore-existing --server="https://kcp.api.portal.dev.local:8443/clusters/root:providers"
kubectl apply -k ./local-setup/example-data/root/providers/infra-provider/ --server="https://kcp.api.portal.dev.local:8443/clusters/root:providers:infra-provider"
kubectl apply -k ./local-setup/example-data/root/providers/httpbin-provider --server="https://kcp.api.portal.dev.local:8443/clusters/root:providers:httpbin-provider"
kubectl apply -k ./local-setup/example-data/root/platform-mesh-system --server="https://kcp.api.portal.dev.local:8443/clusters/root:platform-mesh-system"

## kubectl apply -k ./local-setup/example-data/root/orgs/openmfp --server="https://kcp.api.portal.dev.local:8443/clusters/root:orgs:openmfp"
## kubectl wait --for=condition=Ready account --timeout=120s my-project --server="https://kcp.api.portal.dev.local:8443/clusters/root:orgs:openmfp"
## kubectl kcp bind apiexport root:providers:infra-provider:infra.provider.example.com --server="https://kcp.api.portal.dev.local:8443/clusters/root:orgs:openmfp:my-project" >/dev/null 2>&1 || true
## kubectl apply -k ./local-setup/example-data/root/orgs/openmfp/my-project --server="https://kcp.api.portal.dev.local:8443/clusters/root:orgs:openmfp:my-project"

unset KUBECONFIG

#- cp $(pwd)/.secret/kcp/admin.kubeconfig $(pwd)/.secret/kcp/admin.kubeconfig-httpbin
#- |
#export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig-httpbin
#kubectl kcp ws use :root:providers:httpbin-provider
#unset KUBECONFIG