#!/bin/bash

DEBUG=${DEBUG:-false}
[ "$DEBUG" = "true" ] && set -x
set -e

COL='\033[92m'
RED='\033[91m'
COL_RES='\033[0m'
KINDEST_VERSION="kindest/node:v1.33.1"

SCRIPT_DIR=$(dirname "$0")

if [ -z "${GH_TOKEN}" ]; then
  echo "Please set GH_TOKEN with read:packages"
  exit 1
else
  ghToken=$GH_TOKEN
fi

ghUser=""
if [ -z "${GH_USER}" ]; then
  if ! command -v gh &> /dev/null; then
    echo "Install gh or set GH_USER"
    exit 1
  else
    ghUser=$(gh api user --jq '.login')
  fi
else
  ghUser=$GH_USER
fi

if [ $(kind get clusters | grep -c platform-mesh) -gt 0 ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Kind cluster already running${COL_RES}"
  kind export kubeconfig --name platform-mesh
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster${COL_RES}"
  kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Installing flux ${COL_RES}"
helm upgrade -i -n flux-system --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set kustomizeController.create=false \
  --set notificationController.create=false

echo -e "${COL}[$(date '+%H:%M:%S')] Starting deployments ${COL_RES}"
if [ "${1}" == "oci" ]; then
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] ARM64 detected${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/oci-arm64
  else
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/oci
  fi
  sleep 10

  kubectl wait --namespace default --for=condition=Ready pods --timeout=120s registry || true
  kubectl port-forward svc/registry 5000:5000 &
  trap 'pkill -f "kubectl port-forward svc/registry 5000:5000"' EXIT

  OCIDIR=$SCRIPT_DIR/../../oci
  for file in "$OCIDIR"/*; do
    [ -f "$file" ] || continue
    ls -l "$file"
    helm push "$file" oci://localhost:5000/platform-mesh
  done
else
  if [[ "$(uname -m)" == "arm64" ]]; then
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default-arm64
  else
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default
  fi
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Creating secrets ${COL_RES}"
kubectl create secret docker-registry github -n platform-mesh-system --docker-server=ghcr.io --docker-username=$ghUser --docker-password=$ghToken --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl apply -f -

# Waits for core components similar to original
kubectl wait --namespace istio-system --for=condition=Ready helmreleases --timeout=120s istio-base || true
kubectl wait --namespace istio-system --for=condition=Ready helmreleases --timeout=120s istio-istiod || true
kubectl wait --namespace istio-system --for=condition=Ready helmreleases --timeout=120s istio-gateway || true

kubectl wait --namespace platform-mesh-system --for=condition=Ready helmreleases --timeout=280s platform-mesh-crds || true
kubectl wait --namespace platform-mesh-system --for=condition=Ready helmreleases --timeout=480s platform-mesh || true

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}\u2665${COL}!${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}Portal: http://localhost:8000${COL_RES}"
