#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../../local-setup/backup/openfga}"

usage() {
  echo "Usage: $0 backup [backup-dir]" >&2
  echo "       $0 restore [backup-file]" >&2
  echo >&2
  echo "  backup   — dump OpenFGA data from the dedicated postgres pod (run before changing the profile)" >&2
  echo "  restore  — restore into the shared CNPG cluster (run after applying the updated profile)" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# backup: dump the postgres database from the old dedicated OpenFGA pod
# ---------------------------------------------------------------------------
backup() {
  local backup_dir="${1:-$BACKUP_DIR}"
  mkdir -p "$backup_dir"

  local timestamp
  timestamp=$(date +%F-%T)
  local backup_file="$backup_dir/backup-$timestamp.sql"

  echo "=== OpenFGA Migration: Backup ==="

  echo "Step 1: Waiting for openfga-postgres-0..."
  kubectl wait pod/openfga-postgres-0 \
    -n platform-mesh-system \
    --for=condition=Ready \
    --timeout=120s

  local pgpassword
  pgpassword=$(kubectl get secret openfga-postgres \
    -n platform-mesh-system \
    -o jsonpath='{.data.postgres-password}' | base64 -d)

  echo "Step 2: Dumping OpenFGA database..."
  kubectl exec -n platform-mesh-system openfga-postgres-0 -- \
    bash -c "PGPASSWORD='$pgpassword' pg_dump -U postgres -d postgres" \
    > "$backup_file"

  echo "=== Backup complete ==="
  echo "Backup file: $backup_file"
  echo
  echo "Next: apply the updated profile, then run:"
  echo "  $0 restore $backup_file"
}

# ---------------------------------------------------------------------------
# restore: restore the dump into the shared CNPG openfga database
# ---------------------------------------------------------------------------
restore() {
  local backup_file="${1:-}"

  if [[ -z "$backup_file" ]]; then
    backup_file=$(ls -t "$BACKUP_DIR"/backup-*.sql 2>/dev/null | head -1 || true)
  fi

  if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
    echo "Error: no backup file found. Pass it explicitly: $0 restore <backup-file>" >&2
    exit 1
  fi

  echo "=== OpenFGA Migration: Restore ==="
  echo "Backup file: $backup_file"

  echo "Step 1: Waiting for CNPG primary pod (platform-mesh-pg-1)..."
  kubectl wait pod/platform-mesh-pg-1 \
    -n platform-mesh-system \
    --for=condition=Ready \
    --timeout=180s

  echo "Step 2: Waiting for openfga-db Database CR to be ready..."
  kubectl wait database/openfga-db \
    -n platform-mesh-system \
    --for=jsonpath='.status.applied'=true \
    --timeout=120s

  echo "Step 3: Scaling down OpenFGA..."
  local original_replicas
  original_replicas=$(kubectl get deployment openfga \
    -n platform-mesh-system \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
  kubectl scale deployment openfga -n platform-mesh-system --replicas=0
  kubectl wait deployment openfga \
    -n platform-mesh-system \
    --for=jsonpath='.status.availableReplicas'=0 \
    --timeout=60s 2>/dev/null || true

  echo "Step 4: Resetting openfga schema in CNPG..."
  kubectl exec -n platform-mesh-system platform-mesh-pg-1 -- \
    psql -U postgres -d openfga -c \
      "DROP SCHEMA public CASCADE;
       CREATE SCHEMA public;
       GRANT ALL ON SCHEMA public TO openfga;
       GRANT ALL ON SCHEMA public TO public;"

  echo "Step 5: Restoring from backup..."
  kubectl exec -i -n platform-mesh-system platform-mesh-pg-1 -- \
    psql -U postgres -d openfga \
    < "$backup_file"

  echo "Step 5b: Reassigning table ownership from postgres to openfga..."
  kubectl exec -n platform-mesh-system platform-mesh-pg-1 -- \
    psql -U postgres -d openfga -c "
DO \$\$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' OWNER TO openfga';
  END LOOP;
END;
\$\$;"

  echo "Step 5c: Granting table and sequence access..."
  kubectl exec -n platform-mesh-system platform-mesh-pg-1 -- \
    psql -U postgres -d openfga -c "
      GRANT ALL ON ALL TABLES IN SCHEMA public TO openfga;
      GRANT ALL ON ALL TABLES IN SCHEMA public TO PUBLIC;
      GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO openfga;
      GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO PUBLIC;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO openfga;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO PUBLIC;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO openfga;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO PUBLIC;"

  echo "Step 6: Scaling OpenFGA back up ($original_replicas replica(s))..."
  kubectl scale deployment openfga \
    -n platform-mesh-system \
    --replicas="$original_replicas"
  kubectl rollout status deployment/openfga \
    -n platform-mesh-system \
    --timeout=300s

  echo "=== Restore complete ==="
}

# ---------------------------------------------------------------------------

CMD="${1:-}"
shift || true

case "$CMD" in
  backup)  backup  "$@" ;;
  restore) restore "$@" ;;
  *)       usage ;;
esac
