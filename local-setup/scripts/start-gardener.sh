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

SCRIPT_DIR=$(dirname "$0")
GARDENER_DIR="$SCRIPT_DIR/../gardener/gardener"

usage() {
  echo "Usage: $0 [--help]"
  echo ""
  echo "Bootstrap a local Gardener environment with a shoot cluster."
  echo "This creates a 'gardener-local' Kind cluster and a 'platform-mesh' shoot."
  echo ""
  echo "Options:"
  echo "  --help          Show this help message"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage ;;
    --*) echo "Unknown option: $1" >&2; usage ;;
    *) echo "Ignoring positional arg: $1" ;;
  esac
  shift
done

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Starting Gardener Local Setup ${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"

# Clone gardener if not present
if [ ! -d "$GARDENER_DIR" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Cloning Gardener repository... ${COL_RES}"
    git clone https://github.com/gardener/gardener.git "$GARDENER_DIR"
else
    echo -e "${COL}[$(date '+%H:%M:%S')] Gardener repository already exists at $GARDENER_DIR ${COL_RES}"
fi

# Check if gardener-local kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^gardener-local$"; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Setting up Gardener local environment... ${COL_RES}"
    pushd "$GARDENER_DIR" > /dev/null
    make kind-up gardener-up
    popd > /dev/null
else
    echo -e "${COL}[$(date '+%H:%M:%S')] Gardener-local Kind cluster already exists ${COL_RES}"
fi

# Switch to gardener context
kubectl config use-context kind-gardener-local

# Check if shoot exists
if ! kubectl -n garden-local get shoot platform-mesh &>/dev/null; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating Gardener shoot 'platform-mesh'... ${COL_RES}"
    kubectl apply -f "$SCRIPT_DIR/../gardener/shoot.yaml"
else
    echo -e "${COL}[$(date '+%H:%M:%S')] Shoot 'platform-mesh' already exists ${COL_RES}"
fi

# Wait for shoot to be ready
echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for Gardener shoot to be ready... ${COL_RES}"
NAMESPACE=garden-local "$GARDENER_DIR/hack/usage/wait-for.sh" shoot platform-mesh \
    APIServerAvailable ControlPlaneHealthy ObservabilityComponentsHealthy \
    EveryNodeReady SystemComponentsHealthy

# Generate admin kubeconfig
echo -e "${COL}[$(date '+%H:%M:%S')] Generating shoot admin kubeconfig... ${COL_RES}"
mkdir -p "$SCRIPT_DIR/../../.secret/gardener"
KUBECONFIG_PATH="$SCRIPT_DIR/../../.secret/gardener/shoot-kubeconfig.yaml"
"$GARDENER_DIR/hack/usage/generate-admin-kubeconf.sh" --namespace garden-local --shoot-name platform-mesh > "$KUBECONFIG_PATH"

# Add /etc/hosts entries for shoot API server access if not present
SHOOT_API_DOMAIN="api.platform-mesh.local.external.local.gardener.cloud"
if ! grep -q "$SHOOT_API_DOMAIN" /etc/hosts; then
    echo -e "${YELLOW}⚠️  Adding /etc/hosts entries for shoot cluster access (requires sudo)${COL_RES}"
    sudo tee -a /etc/hosts > /dev/null <<EOF

# Gardener local setup - platform-mesh shoot
172.18.255.1 api.platform-mesh.local.external.local.gardener.cloud
172.18.255.1 api.platform-mesh.local.internal.local.gardener.cloud
EOF
fi

# Convert to absolute path for display
ABSOLUTE_KUBECONFIG_PATH=$(cd "$(dirname "$KUBECONFIG_PATH")" && pwd)/$(basename "$KUBECONFIG_PATH")

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Gardener Setup Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo ""
echo -e "${COL}Gardener shoot 'platform-mesh' is ready!${COL_RES}"
echo ""
echo -e "To access the shoot cluster, run:"
echo -e "  ${YELLOW}export KUBECONFIG=$ABSOLUTE_KUBECONFIG_PATH${COL_RES}"
echo ""
echo -e "To access the Gardener seed cluster, run:"
echo -e "  ${YELLOW}kubectl config use-context kind-gardener-local${COL_RES}"
echo ""

exit 0
