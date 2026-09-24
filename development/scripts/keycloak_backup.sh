#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-${BACKUP_DIR:-development/backup/keycloak/postgres}}"
TIMESTAMP=$(date +%Y-%m-%d-%H:%M:%S)

mkdir -p "$BACKUP_DIR"

# Auto-detect 0.3 (bitnami/standalone postgres) vs 0.4+ (cnpg cluster)
if kubectl get pod keycloak-postgresql-keycloak-0 -n platform-mesh-system &>/dev/null; then
  # 0.3: bitnami postgres
  PGPASSWORD=$(kubectl get secret keycloak-postgresql-keycloak \
    -n platform-mesh-system \
    -o jsonpath='{.data.password}' | base64 -d)
  kubectl exec -n platform-mesh-system keycloak-postgresql-keycloak-0 -- \
    bash -c "PGPASSWORD=$PGPASSWORD pg_dump -U keycloak bitnami_keycloak" \
    > "$BACKUP_DIR/backup-${TIMESTAMP}.sql"
  kubectl get secret keycloak-postgresql-keycloak -n platform-mesh-system -o yaml \
    > "$BACKUP_DIR/keycloak-postgresql-keycloak.yaml"
else
  # 0.4+: cnpg cluster
  PGPASSWORD=$(kubectl get secret keycloak-db-credentials \
    -n platform-mesh-system \
    -o jsonpath='{.data.password}' | base64 -d)
  kubectl exec -n platform-mesh-system platform-mesh-pg-1 -- \
    bash -c "PGPASSWORD=$PGPASSWORD pg_dump -h localhost -U keycloak keycloak" \
    > "$BACKUP_DIR/backup-${TIMESTAMP}.sql"
  kubectl get secret keycloak-db-credentials -n platform-mesh-system -o yaml \
    > "$BACKUP_DIR/keycloak-db-credentials.yaml"
fi

echo "Keycloak backup saved to $BACKUP_DIR/backup-${TIMESTAMP}.sql"
