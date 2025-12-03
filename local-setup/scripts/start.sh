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

KINDEST_VERSION="kindest/node:v1.34.0"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
LATEST=false

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--latest] [--help]"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --latest) LATEST=true ;;
    --help|-h) usage ;;
    --*) echo "Unknown option: $1" >&2; usage ;;
    *) echo "Ignoring positional arg: $1" ;;
  esac
  shift
done

# Source compatibility and environment checks
source "$SCRIPT_DIR/check-wsl-compatibility.sh"
source "$SCRIPT_DIR/check-environment.sh"
source "$SCRIPT_DIR/setup-registry-proxies.sh"

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
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
    $SCRIPT_DIR/../scripts/gen-certs.sh

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached image ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-cached.yaml --name platform-mesh --image=$KINDEST_VERSION
    else
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION
    fi
fi

mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "*.dev.local" "*.portal.dev.local" "*.services.portal.dev.local" "oci-registry-docker-registry.registry.svc.cluster.local"
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

echo -e "${COL}[$(date '+%H:%M:%S')] Installing flux ${COL_RES}"
helm upgrade -i -n flux-system --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
  --version 2.17.1 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set notificationController.create=false \
  --set helmController.container.additionalArgs[0]="--concurrent=50" \
  --set sourceController.container.additionalArgs[1]="--requeue-dependency=5s"

kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=120s helm-controller
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=120s source-controller
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=120s kustomize-controller

echo -e "${COL}[$(date '+%H:%M:%S')] Install KRO and OCM ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/base

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=480s kro

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
  --timeout=480s platform-mesh-operator

if [ "$LATEST" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Using LATEST OCM Component version ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default-latest
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Using RELEASED OCM Component version ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default
fi

kubectl wait --namespace default \
  --for=condition=Ready PlatformMeshOperator \
  --timeout=480s platform-mesh-operator
kubectl wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=120s

if [ "$EXAMPLE_DATA" = true ]; then
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
  --timeout=580s platform-mesh

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s keycloak
kubectl delete pod -l pkg.crossplane.io/provider=provider-keycloak -n crossplane-system

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for helmreleases ${COL_RES}"
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s rebac-authz-webhook
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s account-operator
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=480s portal
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s security-operator

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing KCP Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

if [ "$EXAMPLE_DATA" = true ]; then
  export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
  kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://kcp.api.portal.dev.local:8443/clusters/root"
  kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://kcp.api.portal.dev.local:8443/clusters/root:providers"
  kubectl apply -k $SCRIPT_DIR/../example-data/root/providers/httpbin-provider --server="https://kcp.api.portal.dev.local:8443/clusters/root:providers:httpbin-provider"
  unset KUBECONFIG

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=280s api-syncagent

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=280s example-httpbin-provider

fi

echo -e "${COL}Please create an entry in your /etc/hosts with the following line: \"127.0.0.1 default.portal.dev.local portal.dev.local kcp.api.portal.dev.local httpbin.services.portal.dev.local\" ${COL_RES}"
show_wsl_hosts_guidance

echo -e "${YELLOW}⚠️  WARNING: You need to add a hosts entry for every organization that is onboarded!${COL_RES}"
echo -e "${YELLOW}   Each organization will require its own subdomain entry in /etc/hosts${COL_RES}"
echo -e "${YELLOW}   Example: 127.0.0.1 <organization-name>.portal.dev.local${COL_RES}"

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.dev.local:8443 , any send emails can be received here: https://portal.dev.local:8443/mailpit ${COL_RES}"

if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
