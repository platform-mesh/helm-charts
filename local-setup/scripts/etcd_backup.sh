#!/bin/bash
set -e

# Configuration Variables
NAMESPACE="platform-mesh-system"
POD="etcd-kcp-0"
DEBUG_CONTAINER_NAME="debug-backup-bot" # Unique name to avoid conflicts with existing 'debug' containers
IMAGE="europe-docker.pkg.dev/gardener-project/snapshots/gardener/etcdbrctl:v0.41.0-dev"
LOCAL_BACKUP_DIR="./backup/etcd"
SNAPSHOT_DURATION="15s" # How long to run the snapshotter (simulates waiting before Ctrl+C)

# 1. Create Local Directory
echo "--- Setting up local backup directory: $LOCAL_BACKUP_DIR ---"
mkdir -p "$LOCAL_BACKUP_DIR"

# 2. Start Debug Container in Background
# We run 'sleep 600' to keep the container alive long enough to run exec and cp commands.
echo "--- Spawning ephemeral debug container ($DEBUG_CONTAINER_NAME) ---"
kubectl -n "$NAMESPACE" debug "$POD" \
    -c "$DEBUG_CONTAINER_NAME" \
    --image="$IMAGE" \
    --quiet \
    -- sh -c "sleep 600" &

# Capture the background PID of the kubectl command
KUBECTL_PID=$!

# Wait for the container to be ready
echo "Waiting for debug container to initialize..."
sleep 10

# 3. Run the Snapshot Command
# We use 'timeout' to run the command for a set time, then kill it (simulating Ctrl+C)
# We accept exit code 124 (timeout) or 137 (kill) as success.
echo "--- Running etcdbrctl snapshot for $SNAPSHOT_DURATION ---"
set +e
kubectl -n "$NAMESPACE" exec "$POD" -c "$DEBUG_CONTAINER_NAME" -- \
    timeout "$SNAPSHOT_DURATION" ./etcdbrctl snapshot \
    --storage-provider="Local" \
    --store-container="/tmp/etcd-backup" \
    --endpoints http://localhost:2379 \
    --schedule "* * * * *" \
    --delta-snapshot-period=0s
set -e

echo "--- Snapshot window finished ---"

# 4. Identify the generated file
# We list the directory and grab the last created file (tail -n 1)
echo "--- Identifying latest snapshot ---"
LATEST_SNAPSHOT=$(kubectl -n "$NAMESPACE" exec "$POD" -c "$DEBUG_CONTAINER_NAME" -- ls /tmp/etcd-backup/v2 | grep "Full" | tail -n 1 | tr -d '\r')

if [ -z "$LATEST_SNAPSHOT" ]; then
    echo "Error: No snapshot file found!"
    kill $KUBECTL_PID 2>/dev/null || true
    exit 1
fi

echo "Found snapshot: $LATEST_SNAPSHOT"

# 5. Copy the file to host
echo "--- Copying to host machine ---"
kubectl cp "$NAMESPACE/$POD:tmp/etcd-backup/v2/$LATEST_SNAPSHOT" "$LOCAL_BACKUP_DIR/$LATEST_SNAPSHOT.final" -c "$DEBUG_CONTAINER_NAME"

# 6. Cleanup
echo "--- Backup complete. File saved to $LOCAL_BACKUP_DIR/$LATEST_SNAPSHOT.final ---"
echo "Cleaning up local background processes..."
kill $KUBECTL_PID 2>/dev/null || true

# Note: The ephemeral container inside the pod will remain in 'Terminated' or 'Completed' state 
# until the pod is restarted, but it consumes no resources.