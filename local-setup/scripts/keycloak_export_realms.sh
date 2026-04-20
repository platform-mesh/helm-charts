#!/usr/bin/env bash
set -euo pipefail

EXPORT_DIR="${EXPORT_DIR:-local-setup/backup/keycloak/realms}"
TIMESTAMP=$(date +%Y-%m-%d-%H:%M:%S)
DEST="$EXPORT_DIR/$TIMESTAMP"

mkdir -p "$DEST"

# ADMIN_PASSWORD=$(kubectl get secret keycloak-admin \
#   -n platform-mesh-system \
#   -o jsonpath='{.data.admin-password}' | base64 -d)
# echo "Admin password: $ADMIN_PASSWORD"
ADMIN_PASSWORD=admin

KCADM_BIN=/opt/bitnami/keycloak/bin/kcadm.sh
KC_EXEC="kubectl exec -n platform-mesh-system keycloak-0 --"
KC_CONFIG=/tmp/kcadm.config

$KC_EXEC $KCADM_BIN config credentials \
  --config $KC_CONFIG \
  --server http://localhost:8080/keycloak \
  --realm master \
  --user keycloak-admin \
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
