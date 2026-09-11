#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-local-setup/backup/keycloak/postgres}"

# Use the most recent backup unless BACKUP_FILE is set explicitly
BACKUP_FILE="${BACKUP_FILE:-$(ls -t "$BACKUP_DIR"/backup-*.sql | head -1)}"

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo "Error: no backup file found in $BACKUP_DIR" >&2
  echo "Set BACKUP_FILE=<path> to specify one explicitly." >&2
  exit 1
fi

echo "=== Keycloak Restore Script ==="
echo "Backup file: $BACKUP_FILE"

echo "Step 1: Waiting for Keycloak PostgreSQL pod..."
kubectl wait pod/keycloak-postgresql-keycloak-0 \
  -n platform-mesh-system \
  --for=condition=Ready \
  --timeout=120s

PGPASSWORD=$(kubectl get secret keycloak-postgresql-keycloak \
  -n platform-mesh-system \
  -o jsonpath='{.data.password}' | base64 -d)

echo "Step 2: Terminating active connections to bitnami_keycloak..."
kubectl exec -n platform-mesh-system keycloak-postgresql-keycloak-0 -- \
  bash -c "PGPASSWORD='$PGPASSWORD' psql -U keycloak -d postgres -c \
    \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity \
      WHERE datname = 'bitnami_keycloak' AND pid <> pg_backend_pid();\""

echo "Step 3: Dropping and recreating database..."
kubectl exec -n platform-mesh-system keycloak-postgresql-keycloak-0 -- \
  bash -c "PGPASSWORD='$PGPASSWORD' dropdb -U keycloak bitnami_keycloak"
kubectl exec -n platform-mesh-system keycloak-postgresql-keycloak-0 -- \
  bash -c "PGPASSWORD='$PGPASSWORD' createdb -U keycloak -O keycloak bitnami_keycloak"

echo "Step 4: Restoring from backup..."
kubectl exec -i -n platform-mesh-system keycloak-postgresql-keycloak-0 -- \
  bash -c "PGPASSWORD='$PGPASSWORD' psql -U keycloak bitnami_keycloak" \
  < "$BACKUP_FILE"

echo "Step 5: Restarting Keycloak..."
kubectl rollout restart statefulset/keycloak -n platform-mesh-system
kubectl rollout status statefulset/keycloak -n platform-mesh-system --timeout=120s

echo "=== Keycloak Restore Complete ==="
echo "Backup restored from: $BACKUP_FILE"
