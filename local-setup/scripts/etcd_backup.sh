#!/bin/bash
set -e

NAMESPACE="platform-mesh-system"
POD="etcd-kcp-0"
PVC_CLAIM="etcd-kcp-etcd-kcp-0"
COPY_POD="etcd-backup-copy"
LOCAL_BACKUP_DIR="./local-setup/backup/etcd"

echo "--- Setting up local backup directory: $LOCAL_BACKUP_DIR ---"
mkdir -p "$LOCAL_BACKUP_DIR"

echo "--- Taking etcd snapshot ---"
SNAP_FILE=$(kubectl -n "$NAMESPACE" exec "$POD" -c backup-restore -- \
    /etcdbrctl snapshot \
    --storage-provider=Local \
    --store-container=../../var/etcd/data/backup \
    --endpoints=http://localhost:2379 \
    --schedule='0 0 31 2 *' \
    --delta-snapshot-period=0s 2>&1 | tee /dev/stderr | grep "saved full snapshot at" | grep -o 'Full-[^"]*')

if [ -z "$SNAP_FILE" ]; then
    echo "Error: could not determine snapshot filename"
    exit 1
fi

echo "--- Snapshot saved: $SNAP_FILE ---"

echo "--- Spinning up copy pod ---"
kubectl run -n "$NAMESPACE" "$COPY_POD" \
    --image=busybox --restart=Never \
    --overrides="{
      \"spec\": {
        \"containers\": [{
          \"name\": \"copy\",
          \"image\": \"busybox\",
          \"command\": [\"sleep\", \"300\"],
          \"volumeMounts\": [{\"mountPath\": \"/data\", \"name\": \"etcd-kcp\"}]
        }],
        \"volumes\": [{\"name\": \"etcd-kcp\", \"persistentVolumeClaim\": {\"claimName\": \"$PVC_CLAIM\"}}]
      }
    }"

kubectl wait -n "$NAMESPACE" pod/"$COPY_POD" --for=condition=Ready --timeout=60s

echo "--- Copying snapshot to host ---"
kubectl cp "$NAMESPACE/$COPY_POD:/data/backup/v2/$SNAP_FILE" "$LOCAL_BACKUP_DIR/$SNAP_FILE"

echo "--- Cleaning up copy pod ---"
kubectl delete pod -n "$NAMESPACE" "$COPY_POD"

echo "--- Backup complete: $LOCAL_BACKUP_DIR/$SNAP_FILE ---"
