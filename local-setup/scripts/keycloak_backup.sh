#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-local-setup/backup/keycloak/postgres}"
TIMESTAMP=$(date +%Y-%m-%d-%H:%M:%S)

mkdir -p "$BACKUP_DIR"

PGPASSWORD=$(kubectl get secret keycloak-postgresql-keycloak \
  -n platform-mesh-system \
  -o jsonpath='{.data.password}' | base64 -d)

kubectl exec -n platform-mesh-system keycloak-postgresql-keycloak-0 -- \
  bash -c "PGPASSWORD=$PGPASSWORD pg_dump -U keycloak bitnami_keycloak" \
  > "$BACKUP_DIR/backup-${TIMESTAMP}.sql"

kubectl get secret keycloak-postgresql-keycloak -n platform-mesh-system -o yaml \
  > "$BACKUP_DIR/keycloak-postgresql-keycloak.yaml"

echo "Keycloak backup saved to $BACKUP_DIR/backup-${TIMESTAMP}.sql"
