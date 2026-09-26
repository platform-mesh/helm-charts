#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform-mesh-system}"
POD="${POD:-keycloak-postgresql-keycloak-0}"
SECRET="${SECRET:-keycloak-postgresql-keycloak}"
PG_DATA="/bitnami/postgresql/data"
PG_HBA="${PG_DATA}/pg_hba.conf"

PASSWORD=$(kubectl get secret "$SECRET" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)

# Prepend trust rule so we can connect without a password
kubectl exec -n "$NAMESPACE" "$POD" -- bash -c "
  cp ${PG_HBA} ${PG_HBA}.bak
  printf 'local all all trust\n' | cat - ${PG_HBA}.bak > /tmp/pg_hba_new.conf
  cp /tmp/pg_hba_new.conf ${PG_HBA}
  pg_ctl reload -D ${PG_DATA}
"

# Reset the keycloak user password to match the secret, then restore pg_hba
kubectl exec -n "$NAMESPACE" "$POD" -- bash -c "
  psql -U postgres -c \"ALTER USER keycloak PASSWORD '${PASSWORD}';\"
  cp ${PG_HBA}.bak ${PG_HBA}
  pg_ctl reload -D ${PG_DATA}
"

# Verify
kubectl exec -n "$NAMESPACE" "$POD" -- bash -c \
  "PGPASSWORD=${PASSWORD} psql -U keycloak -d bitnami_keycloak -c '\conninfo'"

echo "keycloak PostgreSQL password synced successfully"
