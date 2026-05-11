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
 KINDEST_VERSION="kindest/node:v1.35.1"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
CONCURRENT=false
SHARDED=false

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--concurrent] [--sharded] [--help]"
  echo ""
  echo "Options:"
  echo "  --prerelease    Deploy with locally built OCM components instead of released versions"
  echo "  --cached        Use local Docker registry mirrors for faster image pulls"
  echo "  --example-data  Install with example provider data (requires kubectl-kcp plugin)"
  echo "  --concurrent    Run prerelease chart builds in parallel instead of sequentially"
  echo "  --sharded       Deploy additional kcp shards"
  echo "  --help          Show this help message"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --concurrent) CONCURRENT=true ;;
    --sharded) SHARDED=true ;;
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

    KIND_QUIET_FLAG="--quiet"
    if [ "$DEBUG" = "true" ]; then
        KIND_QUIET_FLAG=""
    fi

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached images ${COL_RES}"

        # Create temporary kind config with absolute path for containerd certs
        TEMP_KIND_CONFIG=$(mktemp)
        CERTS_DIR=$(cd "$SCRIPT_DIR/../kind/containerd-certs.d" && pwd)
        sed "s|./containerd-certs.d|${CERTS_DIR}|" "$SCRIPT_DIR/../kind/kind-config-cached.yaml" > "$TEMP_KIND_CONFIG"

        kind create cluster --config "$TEMP_KIND_CONFIG" --name platform-mesh --image=$KINDEST_VERSION $KIND_QUIET_FLAG
        rm -f "$TEMP_KIND_CONFIG"
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION $KIND_QUIET_FLAG
    fi
fi

mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "localhost" "*.localhost" "portal.localhost" "*.portal.localhost" "*.services.portal.localhost" "oci-registry-docker-registry.registry.svc.cluster.local" 2>/dev/null
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

echo -e "${COL}[$(date '+%H:%M:%S')] Installing flux ${COL_RES}"
helm upgrade -i -n flux-system --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
  --version 2.17.2 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set notificationController.create=false \
  --set-json 'helmController.container.additionalArgs=["--concurrent=50"]' \
  --set-json 'sourceController.container.additionalArgs=["--requeue-dependency=5s"]' > /dev/null 2>&1

kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=$KUBECTL_WAIT_TIMEOUT helm-controller > /dev/null 2>&1
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=$KUBECTL_WAIT_TIMEOUT source-controller > /dev/null 2>&1
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=$KUBECTL_WAIT_TIMEOUT kustomize-controller > /dev/null 2>&1

# Run post-flux hook if it exists (Flux is ready at this point)
if [ -f "$SCRIPT_DIR/post-flux-hook.sh" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running post-flux hook ${COL_RES}"
    source "$SCRIPT_DIR/post-flux-hook.sh"
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Install KRO and OCM ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/base

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT kro

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=$KUBECTL_WAIT_TIMEOUT ocm-k8s-toolkit

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

# kind load image-archive image.tar --name platform-mesh
# kind load docker-image ghcr.io/platform-mesh/platform-mesh-operator:v0.41.9 --name platform-mesh
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

# Apply PlatformMesh resource: use hook if available, otherwise use default overlay logic
if [ -f "$SCRIPT_DIR/platform-mesh-resource-hook.sh" ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Running platform-mesh-resource hook ${COL_RES}"
  source "$SCRIPT_DIR/platform-mesh-resource-hook.sh"
elif [ "$PRERELEASE" = true ]; then
  if [ "$EXAMPLE_DATA" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease with example-data) ${COL_RES}"
    # TODO: Create example-data-prerelease overlay if needed
    if [ "$SHARDED" = true ]; then
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease-sharded
    else
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
    fi
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
  else
    if [ "$SHARDED" = true ]; then
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease sharded) ${COL_RES}"
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease-sharded
    else
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease) ${COL_RES}"
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
    fi
  fi
else
  if [ "$SHARDED" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (sharded) ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-sharded
  else
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource
  fi
  if [ "$EXAMPLE_DATA" = true ]; then
    if [ "$SHARDED" = true ]; then
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data-sharded
    else
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
    fi
  fi
fi

# wait for kind: PlatformMesh resource to become ready
echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for kind: PlatformMesh resource to become ready ${COL_RES}"
kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready platformmesh \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing kcp Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

# Run post-platform-mesh hook if it exists (PlatformMesh is ready, kcp is accessible)
if [ -f "$SCRIPT_DIR/post-platform-mesh-hook.sh" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running post-platform-mesh hook ${COL_RES}"
    KCP_KUBECONFIG="$(pwd)/.secret/kcp/admin.kubeconfig" source "$SCRIPT_DIR/post-platform-mesh-hook.sh"
fi

if [ "$EXAMPLE_DATA" = true ]; then

  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://localhost:8443/clusters/root"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://localhost:8443/clusters/root:providers"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl apply -k $SCRIPT_DIR/../example-data/root/providers/httpbin-provider --server="https://localhost:8443/clusters/root:providers:httpbin-provider"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl apply -k $SCRIPT_DIR/../example-data/root/orgs --server="https://localhost:8443/clusters/root:orgs"

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT api-syncagent

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT example-httpbin-provider

fi

echo -e "${COL}[$(date '+%H:%M:%S')] Installing observability stack ${COL_RES}"
helm dependency update "$SCRIPT_DIR/../../charts/observability" > /dev/null 2>&1
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install observability "$SCRIPT_DIR/../../charts/observability" -n observability \
  --set prometheus.server.persistentVolume.enabled=false \
  --wait --timeout=5m > /dev/null 2>&1

echo -e "${COL}[$(date '+%H:%M:%S')] Verifying backend resources ${COL_RES}"
"$SCRIPT_DIR/check-backend-resources.sh"

echo -e "${YELLOW}⚠️  NOTE: Organization subdomains like <organization-name>.portal.localhost are resolved automatically by modern browsers.${COL_RES}"
echo -e "${YELLOW}   No /etc/hosts entries are needed for browser access.${COL_RES}"
show_wsl_hosts_guidance

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Saving kcp root CA certificate ${COL_RES}"
kubectl -n platform-mesh-system get secret root-ca -oyaml | yq '.data["ca.crt"]' | base64 -d > $SCRIPT_DIR/certs/root-ca.crt

echo -e "${YELLOW}⚠️  Add the following entry to /etc/hosts if not already present:${COL_RES}"
echo 'echo "127.0.0.1 kcp.root.localhost" | sudo tee -a /etc/hosts'

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.localhost:8443 ${COL_RES}"


if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
