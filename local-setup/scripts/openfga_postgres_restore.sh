#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../backup/fga/postgres"
NAMESPACE="platform-mesh-system"
PVC_NAME="data-openfga-postgres-0"
POD_NAME="openfga-postgres-0"

echo "=== OpenFGA PostgreSQL Restore Script ==="

# Step 1: Find the latest backup file
echo "Step 1: Finding latest backup file..."
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

BACKUP_FILE=$(ls -t "$BACKUP_DIR"/backup-*.sql 2>/dev/null | head -n 1)
if [ -z "$BACKUP_FILE" ]; then
    echo "Error: No backup files found in $BACKUP_DIR"
    exit 1
fi
echo "Using backup file: $BACKUP_FILE"

# Step 2: Get PV name from PVC (before deleting anything)
echo "Step 2: Getting PV name from PVC..."
PV_NAME=$(kubectl -n "$NAMESPACE" get pvc "$PVC_NAME" -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)
if [ -n "$PV_NAME" ]; then
    echo "Found PV: $PV_NAME"
else
    echo "Warning: PVC $PVC_NAME not found or has no bound PV"
fi

# Step 3: Delete the pod first (must release PVC before it can be deleted)
echo "Step 3: Deleting pod $POD_NAME..."
kubectl -n "$NAMESPACE" delete pod "$POD_NAME" --ignore-not-found --wait=true

# Step 4: Delete PVC
echo "Step 4: Deleting PVC $PVC_NAME..."
kubectl -n "$NAMESPACE" delete pvc "$PVC_NAME" --ignore-not-found --wait=true

# Step 5: Delete PV if it was found
if [ -n "$PV_NAME" ]; then
    echo "Step 5: Deleting PV $PV_NAME..."
    kubectl delete pv "$PV_NAME" --ignore-not-found
fi

# Step 6: Wait for pod to be recreated and ready
echo "Step 6: Waiting for pod $POD_NAME to be recreated and ready..."
echo "  (This may take a while as a new PVC/PV will be provisioned)"

MAX_WAIT=300
WAIT_INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    POD_STATUS=$(kubectl -n "$NAMESPACE" get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    READY=$(kubectl -n "$NAMESPACE" get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")

    if [ "$POD_STATUS" = "Running" ] && [ "$READY" = "true" ]; then
        echo "  Pod is ready!"
        break
    fi

    echo "  Pod status: $POD_STATUS, Ready: $READY (waited ${ELAPSED}s)"
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "Error: Timed out waiting for pod to be ready"
    exit 1
fi

# Give postgres a moment to fully initialize
echo "  Waiting for PostgreSQL to initialize..."
sleep 10

# Step 7: Restore the backup
echo "Step 7: Restoring PostgreSQL backup..."
cat "$BACKUP_FILE" | kubectl -n "$NAMESPACE" exec -i pod/"$POD_NAME" -- env PGPASSWORD='password' psql -U postgres

echo "=== OpenFGA PostgreSQL Restore Complete ==="
