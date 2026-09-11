#!/usr/bin/env bash
set -euo pipefail

EXPORT_DIR="${1:-${EXPORT_DIR:-local-setup/backup/keycloak/realms}}"
TIMESTAMP=$(date +%Y-%m-%d-%H:%M:%S)
DEST="$EXPORT_DIR/$TIMESTAMP"

mkdir -p "$DEST"

ADMIN_USER=$(kubectl get secret keycloak-admin \
  -n platform-mesh-system \
  -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASSWORD=$(kubectl get secret keycloak-admin \
  -n platform-mesh-system \
  -o jsonpath='{.data.password}' | base64 -d)

KCADM_BIN=/opt/keycloak/bin/kcadm.sh
KC_EXEC="kubectl exec -n platform-mesh-system keycloak-0 --"
KC_CONFIG=/tmp/kcadm.config

$KC_EXEC $KCADM_BIN config credentials \
  --config $KC_CONFIG \
  --server http://localhost:8080/keycloak \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASSWORD"

REALMS=$($KC_EXEC $KCADM_BIN get realms \
  --config $KC_CONFIG \
  --fields realm --format csv --noquotes | tail -n +1)

for REALM in $REALMS; do
  echo "Exporting realm: $REALM"
  $KC_EXEC $KCADM_BIN get realms/"$REALM" --config $KC_CONFIG > "$DEST/${REALM}.json"
  $KC_EXEC $KCADM_BIN get clients -r "$REALM" --config $KC_CONFIG > "$DEST/${REALM}-clients.json"
done

echo "Realm exports saved to $DEST"
