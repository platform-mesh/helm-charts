#!/bin/bash

DEBUG=${DEBUG:-false}

if [ "${DEBUG}" = "true" ]; then
  set -x
fi

set -e

COL='\033[92m'
RED='\033[91m'
COL_RES='\033[0m'
KINDEST_VERSION="kindest/node:v1.33.1"

SCRIPT_DIR=$(dirname "$0")

if [ -z "${GH_TOKEN}" ]; then
  echo "Please set the 'GH_TOKEN' environment variable with a GitHub token that has 'read:packages' scope."
  exit 1
else
  ghToken=$GH_TOKEN
fi

ghUser=""
if [ -z "${GH_USER}" ]; then
  if ! command -v gh &> /dev/null; then
    echo "gh CLI could not be found. Either install the gh cli or set the GH_USER environment variable with your GitHub username."
    exit 1
  else
    ghUser=$(gh api user --jq '.login')
  fi
else
  ghUser=$GH_USER
fi

if [ $(kind get clusters | grep -c platform-mesh) -gt 0 ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Kind cluster already running, using existing ${COL_RES}"
  kind export kubeconfig --name platform-mesh
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
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
    echo -e "${COL}[$(date '+%H:%M:%S')] ARM64 architecture detected, applying patch ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/oci-arm64
  else
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/oci
  fi
  sleep 10

  kubectl wait --namespace default \
    --for=condition=Ready pods \
    --timeout=120s registry

  kubectl port-forward svc/registry 5000:5000 --context kind-platform-mesh &
  sleep 1

  cleanup() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Cleaning up background processes ${COL_RES}"
    pkill -f "kubectl port-forward svc/registry 5000:5000" || true
  }
  trap cleanup EXIT

  OCIDIR=$SCRIPT_DIR/../../oci
  for dir in $OCIDIR; do
    if [ -d "$dir" ]; then
      echo -e "${COL}[$(date '+%H:%M:%S')] Listing files in directory: $dir ${COL_RES}"
      for file in "$dir"/*; do
        echo -e "${COL}[$(date '+%H:%M:%S')] Processing file: $file ${COL_RES}"
        ls -l "$file"
        helm push "$file" oci://localhost:5000/platform-mesh
      done
    else
      echo -e "${COL}[$(date '+%H:%M:%S')] Directory not found: $dir ${COL_RES}"
      exit 1
    fi
  done
else
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] ARM64 architecture detected, applying patch ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default-arm64
  else
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default
  fi
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Creating necessary secrets ${COL_RES}"
kubectl create secret docker-registry github -n platform-mesh-system --docker-server=ghcr.io --docker-username=$ghUser --docker-password=$ghToken --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for istio to become ready ${COL_RES}"
kubectl wait --namespace istio-system \
  --for=condition=Ready helmreleases \
  --timeout=120s istio-base

kubectl wait --namespace istio-system \
  --for=condition=Ready helmreleases \
  --timeout=120s istio-istiod

kubectl wait --namespace istio-system \
  --for=condition=Ready helmreleases \
  --timeout=120s istio-gateway

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for Platform Mesh CRDs to become ready ${COL_RES} (this may take a few minutes)"

kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready helmreleases \
  --timeout=280s platform-mesh-crds

echo -e "$COL Waiting for Platform Mesh to become ready $COL_RES (this may take a while)"

kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready helmreleases \
  --timeout=480s platform-mesh

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL}!${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the portal at: http://localhost:8000${COL_RES}"
exit 0
