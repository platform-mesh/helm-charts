#!/bin/bash
# setup-keycloak-operator.sh - Install Keycloak Operator and deploy Keycloak
# using the operator's Keycloak CR instead of the Bitnami Helm chart.
#
# Usage: source this from start.sh after CNPG setup.

set -e

COL='\033[92m'
COL_RES='\033[0m'
KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-900s}"

KEYCLOAK_IMAGE="ghcr.io/platform-mesh/keycloak"
KEYCLOAK_TAG="26.6.0-optimized"

echo -e "${COL}[$(date '+%H:%M:%S')] Building optimized Keycloak image ${COL_RES}"
docker build -t "$KEYCLOAK_IMAGE:$KEYCLOAK_TAG" "$SCRIPT_DIR/../keycloak"

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

echo -e "${COL}[$(date '+%H:%M:%S')] Creating Keycloak database credentials secret ${COL_RES}"
kubectl create secret generic keycloak-db-credentials \
  --namespace platform-mesh-system \
  --from-literal=username=keycloak \
  --from-literal=password=keycloak-password \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Creating Keycloak bootstrap admin secret ${COL_RES}"
kubectl create secret generic keycloak-admin \
  --namespace platform-mesh-system \
  --from-literal=username=keycloak-admin \
  --from-literal=password=admin \
  --from-literal=secret=admin \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Deploying Keycloak via operator CR ${COL_RES}"
kubectl apply -f - <<EOF
apiVersion: k8s.keycloak.org/v2beta1
kind: Keycloak
metadata:
  name: keycloak
  namespace: platform-mesh-system
spec:
  instances: 1
  image: $KEYCLOAK_IMAGE:$KEYCLOAK_TAG
  db:
    vendor: postgres
    host: platform-mesh-pg-rw.platform-mesh-system.svc.cluster.local
    port: 5432
    database: keycloak
    usernameSecret:
      name: keycloak-db-credentials
      key: username
    passwordSecret:
      name: keycloak-db-credentials
      key: password
  http:
    httpEnabled: true
  ingress:
    enabled: false
  hostname:
    hostname: https://portal.localhost:8443/keycloak
    strict: false
    backchannelDynamic: true
  proxy:
    headers: xforwarded
  bootstrapAdmin:
    user:
      secret: keycloak-admin
  additionalOptions:
    - name: http-relative-path
      value: /keycloak/
  unsupported:
    podTemplate:
      spec:
        containers:
          - imagePullPolicy: IfNotPresent
            resources:
              limits:
                cpu: "2"
                memory: 2Gi
              requests:
                cpu: 750m
                memory: 1Gi
EOF

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for Keycloak to be ready ${COL_RES}"
kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready keycloak/keycloak \
  --timeout="$KUBECTL_WAIT_TIMEOUT"

echo -e "${COL}[$(date '+%H:%M:%S')] Keycloak is ready ${COL_RES}"
echo -e "${COL}  Service: keycloak-service.platform-mesh-system.svc.cluster.local:8080 ${COL_RES}"
