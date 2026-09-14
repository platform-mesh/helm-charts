#!/usr/bin/env bash
set -euo pipefail

EXPORT_DIR="${1:-${EXPORT_DIR:-local-setup/backup/keycloak/realms}}"
TIMESTAMP=$(date +%Y-%m-%d-%H:%M:%S)
DEST="$EXPORT_DIR/$TIMESTAMP"

mkdir -p "$DEST"

KC_EXEC="kubectl exec -n platform-mesh-system keycloak-0 --"
KC_CONFIG=/tmp/kcadm.config

ADMIN_PASSWORD=$(kubectl get secret keycloak-admin \
  -n platform-mesh-system \
  -o jsonpath='{.data.secret}' | base64 -d 2>/dev/null || \
  kubectl get secret keycloak-admin \
  -n platform-mesh-system \
  -o jsonpath='{.data.password}' | base64 -d)

# Auto-detect 0.3 (bitnami, /keycloak/ path) vs 0.4+ (keycloak-operator, /keycloak path)
if $KC_EXEC test -f /opt/bitnami/keycloak/bin/kcadm.sh 2>/dev/null; then
  KCADM_BIN=/opt/bitnami/keycloak/bin/kcadm.sh
  KC_SERVER=http://localhost:8080/keycloak/
else
  KCADM_BIN=/opt/keycloak/bin/kcadm.sh
  KC_SERVER=http://localhost:8080/keycloak
fi

$KC_EXEC $KCADM_BIN config credentials \
  --config $KC_CONFIG \
  --server "$KC_SERVER" \
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
