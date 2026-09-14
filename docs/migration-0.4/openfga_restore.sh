#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-${BACKUP_DIR:-local-setup/backup/openfga/postgres}}"

# Use the most recent backup unless BACKUP_FILE is set explicitly
BACKUP_FILE="${BACKUP_FILE:-$(ls -t "$BACKUP_DIR"/backup-*.sql | head -1)}"

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo "Error: no backup file found in $BACKUP_DIR" >&2
  echo "Set BACKUP_FILE=<path> to specify one explicitly." >&2
  exit 1
fi

echo "=== OpenFGA Postgres Restore ==="
echo "Backup file: $BACKUP_FILE"

echo "Step 1: Waiting for OpenFGA PostgreSQL pod..."
kubectl wait pod/openfga-postgres-0 \
  -n platform-mesh-system \
  --for=condition=Ready \
  --timeout=120s

PGPASSWORD=$(kubectl get secret openfga-postgres \
  -n platform-mesh-system \
  -o jsonpath='{.data.postgres-password}' | base64 -d)

# The pg_dumpall backup restores the postgres role password from the source install.
# If a previous restore already ran, the DB password may differ from the current secret.
# Normalise it first: try the current password, then fall back to known previous values.
echo "Step 1b: Ensuring postgres password matches current secret..."
for try_pass in "$PGPASSWORD" "password" "openfga-password"; do
  if kubectl exec -n platform-mesh-system openfga-postgres-0 -- \
      bash -c "PGPASSWORD='${try_pass}' psql -U postgres -d postgres -c 'SELECT 1'" \
      >/dev/null 2>&1; then
    if [[ "$try_pass" != "$PGPASSWORD" ]]; then
      kubectl exec -n platform-mesh-system openfga-postgres-0 -- \
        bash -c "PGPASSWORD='${try_pass}' psql -U postgres -d postgres -c \
          \"ALTER ROLE postgres WITH PASSWORD '$PGPASSWORD';\""
    fi
    break
  fi
done

echo "Step 2: Dropping all openfga tables..."
kubectl exec -n platform-mesh-system openfga-postgres-0 -- \
  bash -c "PGPASSWORD='$PGPASSWORD' psql -U postgres -d postgres -c \
    'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"

echo "Step 3: Restoring from backup (pg_dumpall)..."
# Strip the ALTER ROLE postgres PASSWORD line — it would reset the postgres password to the
# backup's hash, breaking the subsequent \connect in the same dump.
grep -v "^ALTER ROLE postgres WITH.*PASSWORD" "$BACKUP_FILE" | \
  kubectl exec -i -n platform-mesh-system openfga-postgres-0 -- \
    bash -c "PGPASSWORD='$PGPASSWORD' psql -U postgres postgres"

echo "Step 4: Restarting OpenFGA..."
kubectl rollout restart deployment/openfga -n platform-mesh-system
kubectl rollout status deployment/openfga -n platform-mesh-system --timeout=120s

echo "=== OpenFGA Restore Complete ==="
echo "Backup restored from: $BACKUP_FILE"
