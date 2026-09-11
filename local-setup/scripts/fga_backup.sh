#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${1:-$SCRIPT_DIR/../backup/openfga}"
export BACKUP_DIR
POSTGRES_BACKUP_DIR="$BACKUP_DIR/postgres"
FGA_PORT=18300

echo "=== OpenFGA Backup Script ==="

# Create backup directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$POSTGRES_BACKUP_DIR"

# Step 1: PostgreSQL dump
echo "Step 1: Creating PostgreSQL dump..."
TIMESTAMP=$(date +%F-%T)
BACKUP_FILE="$POSTGRES_BACKUP_DIR/backup-$TIMESTAMP.sql"

kubectl -n platform-mesh-system exec pod/openfga-postgres-0 -- \
    env PGPASSWORD='password' pg_dumpall -U postgres > "$BACKUP_FILE"

echo "PostgreSQL backup saved to: $BACKUP_FILE"

# Step 2: Port-forward OpenFGA so the fga CLI can reach it
echo "Step 2: Starting port-forward to OpenFGA on localhost:${FGA_PORT}..."
kubectl port-forward svc/openfga -n platform-mesh-system "${FGA_PORT}:8080" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null; wait "$PF_PID" 2>/dev/null' EXIT
sleep 2

export FGA_SERVER_URL="http://localhost:${FGA_PORT}"

# Step 3: Export FGA stores using CLI
echo "Step 3: Exporting FGA stores..."
fga store list --server-url "$FGA_SERVER_URL" > "$BACKUP_DIR/store-list.json"
echo "Store list saved to: $BACKUP_DIR/store-list.json"

# Step 4: Export each store
echo "Step 4: Exporting individual stores..."
"$SCRIPT_DIR/export-stores.sh"

echo "=== OpenFGA Backup Complete ==="
