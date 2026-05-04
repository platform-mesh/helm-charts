#!/bin/bash
# setup-keycloak-operator.sh - Build and load the optimized Keycloak image,
# then install the Keycloak Operator helm chart.
#
# Usage: source this from start.sh after CNPG setup.

set -e

COL='\033[92m'
COL_RES='\033[0m'
KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-900s}"

KEYCLOAK_IMAGE="ghcr.io/platform-mesh/custom-images/keycloak"
KEYCLOAK_TAG="26.6.0-local"

echo -e "${COL}[$(date '+%H:%M:%S')] Building optimized Keycloak image ${COL_RES}"
docker build -t "$KEYCLOAK_IMAGE:$KEYCLOAK_TAG" "$SCRIPT_DIR/../../../custom-images/images/keycloak"

echo -e "${COL}[$(date '+%H:%M:%S')] Loading Keycloak image into Kind cluster ${COL_RES}"
kind load docker-image "$KEYCLOAK_IMAGE:$KEYCLOAK_TAG" -n platform-mesh

echo -e "${COL}[$(date '+%H:%M:%S')] Installing Keycloak Operator via Helm ${COL_RES}"
helm upgrade -i keycloak-operator "$SCRIPT_DIR/../../charts/keycloak-operator" \
  --namespace keycloak-system \
  --create-namespace \
  --set watchNamespaces=platform-mesh-system \
  --set keycloakImage.repository="$KEYCLOAK_IMAGE" \
  --set keycloakImage.tag="$KEYCLOAK_TAG" \
  --wait \
  --timeout 5m

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for Keycloak Operator to be ready ${COL_RES}"
kubectl wait --namespace keycloak-system \
  --for=condition=available deployment/keycloak-operator \
  --timeout="$KUBECTL_WAIT_TIMEOUT"
