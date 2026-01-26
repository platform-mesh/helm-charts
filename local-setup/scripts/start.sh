#!/bin/bash

DEBUG=${DEBUG:-false}

if [ "${DEBUG}" = "true" ]; then
  set -x
fi

set -e

COL='\033[92m'
RED='\033[91m'
YELLOW='\033[93m'
COL_RES='\033[0m'

KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-900s}"
KINDEST_VERSION="kindest/node:v1.34.0"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
CONCURRENT=false

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--concurrent] [--help]"
  echo ""
  echo "Options:"
  echo "  --prerelease    Deploy with locally built OCM components instead of released versions"
  echo "  --cached        Use local Docker registry mirrors for faster image pulls"
  echo "  --example-data  Install with example provider data (requires kubectl-kcp plugin)"
  echo "  --concurrent    Run prerelease chart builds in parallel instead of sequentially"
  echo "  --help          Show this help message"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --concurrent) CONCURRENT=true ;;
    --help|-h) usage ;;
    --*) echo "Unknown option: $1" >&2; usage ;;
    *) echo "Ignoring positional arg: $1" ;;
  esac
  shift
done

# Export CONCURRENT for prerelease build scripts
export CONCURRENT

# Source compatibility and environment checks
source "$SCRIPT_DIR/check-wsl-compatibility.sh"
source "$SCRIPT_DIR/check-environment.sh"
source "$SCRIPT_DIR/setup-registry-proxies.sh"
source "$SCRIPT_DIR/setup-prerelease.sh"

# Run WSL compatibility checks
check_wsl_compatibility

# Run environment checks
run_environment_checks

# Start registry proxies if using cached mode
if [ "$CACHED" = true ]; then
    setup_registry_proxies
fi

# Check if kind cluster is already running, if not create it
if ! check_kind_cluster; then
    if [ -d "$SCRIPT_DIR/certs" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Clearing existing certs directory ${COL_RES}"
        rm -rf "$SCRIPT_DIR/certs"
    fi
    $SCRIPT_DIR/../scripts/gen-certs.sh

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached images ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-cached.yaml --name platform-mesh --image=$KINDEST_VERSION --quiet
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION --quiet
    fi
fi

mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "localhost" "*.localhost" "portal.localhost" "*.portal.localhost" "*.services.portal.localhost" "oci-registry-docker-registry.registry.svc.cluster.local" 2>/dev/null
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

echo -e "${COL}[$(date '+%H:%M:%S')] Installing flux ${COL_RES}"
helm upgrade -i -n flux-system --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
  --version 2.17.1 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set notificationController.create=false \
  --set helmController.container.additionalArgs[0]="--concurrent=50" \
  --set sourceController.container.additionalArgs[1]="--requeue-dependency=5s" > /dev/null 2>&1

kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=$KUBECTL_WAIT_TIMEOUT helm-controller > /dev/null 2>&1
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=$KUBECTL_WAIT_TIMEOUT source-controller > /dev/null 2>&1
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=$KUBECTL_WAIT_TIMEOUT kustomize-controller > /dev/null 2>&1

echo -e "${COL}[$(date '+%H:%M:%S')] Install KRO and OCM ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/base

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT kro

echo -e "${COL}[$(date '+%H:%M:%S')] Creating necessary secrets ${COL_RES}"
#kubectl create secret tls iam-authorization-webhook-webhook-ca -n platform-mesh-system --key $SCRIPT_DIR/../webhook-config/ca.key --cert $SCRIPT_DIR/../webhook-config/ca.crt --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic domain-certificate -n default \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic domain-certificate -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic domain-certificate-ca -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/ca.crt --dry-run=client -oyaml | kubectl apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/base/rgd
kubectl wait --namespace default \
  --for=condition=Ready resourcegraphdefinition \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator

if [ "$PRERELEASE" = true ]; then
  run_prerelease_setup
else
  OCM_VERSION=$(yq '.spec.semver' "$SCRIPT_DIR/../kustomize/components/ocm/component.yaml")
  echo -e "${COL}[$(date '+%H:%M:%S')] Using OCM Component version: ${OCM_VERSION} ${COL_RES}"
  kubectl apply -k "$SCRIPT_DIR/../kustomize/overlays/default"
fi

kubectl wait --namespace default \
  --for=condition=Ready PlatformMeshOperator \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator
kubectl wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=$KUBECTL_WAIT_TIMEOUT

if [ "$PRERELEASE" = true ]; then
  if [ "$EXAMPLE_DATA" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease with example-data) ${COL_RES}"
    # TODO: Create example-data-prerelease overlay if needed
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
  else
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease) ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
  fi
elif [ "$EXAMPLE_DATA" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (with example-data) ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource
fi

# wait for kind: PlatformMesh resource to become ready
echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for kind: PlatformMesh resource to become ready ${COL_RES}"
kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready platformmesh \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT keycloak
kubectl delete pod -l pkg.crossplane.io/provider=provider-keycloak -n crossplane-system

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for helmreleases ${COL_RES}"
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT rebac-authz-webhook
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT account-operator
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT portal
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT security-operator

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing KCP Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

if [ "$EXAMPLE_DATA" = true ]; then
  export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
  kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://localhost:8443/clusters/root"
  kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://localhost:8443/clusters/root:providers"
  kubectl apply -k $SCRIPT_DIR/../example-data/root/providers/httpbin-provider --server="https://localhost:8443/clusters/root:providers:httpbin-provider"
  unset KUBECONFIG

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT api-syncagent

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT example-httpbin-provider

fi

echo -e "${YELLOW}⚠️  NOTE: Organization subdomains like <organization-name>.portal.localhost are resolved automatically by modern browsers.${COL_RES}"
echo -e "${YELLOW}   No /etc/hosts entries are needed for browser access.${COL_RES}"
show_wsl_hosts_guidance

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.localhost:8443 , any send emails can be received here: https://portal.localhost:8443/mailpit ${COL_RES}"

if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
