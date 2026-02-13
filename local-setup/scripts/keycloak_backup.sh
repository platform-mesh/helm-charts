#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../backup/keycloak"
POSTGRES_BACKUP_DIR="$BACKUP_DIR/postgres"

echo "=== Keycloak Backup Script ==="

# Create backup directories
mkdir -p "$POSTGRES_BACKUP_DIR"

# Step 1: Get PostgreSQL password from secret
echo "Step 1: Retrieving PostgreSQL password..."
PG_KC_PASS=$(kubectl -n platform-mesh-system get secret keycloak-postgresql-keycloak -oyaml | yq '.data["postgres-password"]' | base64 -d)

# Step 2: PostgreSQL dump
echo "Step 2: Creating PostgreSQL dump..."
TIMESTAMP=$(date +%F-%T)
BACKUP_FILE="$POSTGRES_BACKUP_DIR/backup-$TIMESTAMP.sql"

kubectl -n platform-mesh-system exec pod/keycloak-postgresql-keycloak-0 -- \
    env PGPASSWORD="$PG_KC_PASS" pg_dumpall -U postgres > "$BACKUP_FILE"

echo "PostgreSQL backup saved to: $BACKUP_FILE"

# Step 3: Backup database secret
echo "Step 3: Backing up database secret..."
kubectl -n platform-mesh-system get secret keycloak-postgresql-keycloak -oyaml > "$POSTGRES_BACKUP_DIR/keycloak-postgresql-keycloak.yaml"

echo "Secret backup saved to: $POSTGRES_BACKUP_DIR/keycloak-postgresql-keycloak.yaml"

echo "=== Keycloak Backup Complete ==="
