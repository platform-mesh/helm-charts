#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../backup/fga"
POSTGRES_BACKUP_DIR="$BACKUP_DIR/postgres"

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

# Step 2: Export FGA stores using CLI
echo "Step 2: Exporting FGA stores..."
fga store list > "$BACKUP_DIR/store-list.json"
echo "Store list saved to: $BACKUP_DIR/store-list.json"

# Step 3: Export each store
echo "Step 3: Exporting individual stores..."
"$SCRIPT_DIR/export-stores.sh"

echo "=== OpenFGA Backup Complete ==="
