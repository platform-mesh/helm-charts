#!/bin/bash
# setup-cnpg.sh - Install CloudNativePG operator and create a shared PostgreSQL cluster
# for Keycloak and OpenFGA in the local development environment.
#
# Usage: source this from post-flux-hook.sh, or run standalone.

set -e

COL='\033[92m'
COL_RES='\033[0m'
KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-900s}"

echo -e "${COL}[$(date '+%H:%M:%S')] Installing CloudNativePG operator via Flux HelmRelease ${COL_RES}"
kubectl apply -f - <<'EOF'
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: cnpg
  namespace: default
spec:
  type: oci
  interval: 1h
  url: oci://ghcr.io/cloudnative-pg/charts
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cnpg
  namespace: default
spec:
  releaseName: cnpg
  interval: 1m
  timeout: 15m
  targetNamespace: cnpg-system
  install:
    createNamespace: true
  chart:
    spec:
      chart: cloudnative-pg
      sourceRef:
        kind: HelmRepository
        name: cnpg
EOF

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for CNPG operator to be ready ${COL_RES}"
kubectl wait --namespace default \
  --for=condition=Ready helmreleases/cnpg \
  --timeout="$KUBECTL_WAIT_TIMEOUT"

kubectl create namespace platform-mesh-system --dry-run=client -o yaml | kubectl apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Creating password secrets for managed roles ${COL_RES}"
kubectl create secret generic cnpg-keycloak-user \
  --namespace platform-mesh-system \
  --from-literal=username=keycloak \
  --from-literal=password=keycloak-password \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic cnpg-openfga-user \
  --namespace platform-mesh-system \
  --from-literal=username=openfga \
  --from-literal=password=openfga-password \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Creating CNPG PostgreSQL cluster ${COL_RES}"
kubectl apply -f - <<'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: platform-mesh-pg
  namespace: platform-mesh-system
spec:
  instances: 2

  storage:
    size: 2Gi

  managed:
    roles:
      - name: keycloak
        ensure: present
        login: true
        createdb: false
        passwordSecret:
          name: cnpg-keycloak-user
      - name: openfga
        ensure: present
        login: true
        createdb: false
        passwordSecret:
          name: cnpg-openfga-user

  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "128MB"
EOF

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for CNPG cluster to become ready ${COL_RES}"
kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready cluster/platform-mesh-pg \
  --timeout="$KUBECTL_WAIT_TIMEOUT"

echo -e "${COL}[$(date '+%H:%M:%S')] Creating databases via Database CRDs ${COL_RES}"
kubectl apply -f - <<'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: keycloak-db
  namespace: platform-mesh-system
spec:
  name: keycloak
  owner: keycloak
  cluster:
    name: platform-mesh-pg
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: openfga-db
  namespace: platform-mesh-system
spec:
  name: openfga
  owner: openfga
  cluster:
    name: platform-mesh-pg
EOF

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for databases to be applied ${COL_RES}"
kubectl wait --namespace platform-mesh-system \
  --for=jsonpath='{.status.applied}'=true database/keycloak-db \
  --timeout="$KUBECTL_WAIT_TIMEOUT"
kubectl wait --namespace platform-mesh-system \
  --for=jsonpath='{.status.applied}'=true database/openfga-db \
  --timeout="$KUBECTL_WAIT_TIMEOUT"

echo -e "${COL}[$(date '+%H:%M:%S')] CNPG PostgreSQL cluster is ready ${COL_RES}"
echo -e "${COL}  Service: platform-mesh-pg-rw.platform-mesh-system.svc.cluster.local:5432 ${COL_RES}"
echo -e "${COL}  Databases: keycloak, openfga ${COL_RES}"
