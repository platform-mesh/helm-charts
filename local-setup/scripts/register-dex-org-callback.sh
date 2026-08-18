#!/usr/bin/env bash

set -euo pipefail

ORG="${ORG:-${1:-}}"
BASE_DOMAIN="${BASE_DOMAIN:-portal.localhost}"
NAMESPACE="${NAMESPACE:-platform-mesh-system}"
DEX_CLIENT_ID="${DEX_CLIENT_ID:-keycloak-broker}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-120s}"

usage() {
  cat <<EOF
Usage: $0 <org-name>
   or: ORG=<org-name> $0

Register a Keycloak broker redirect URI for an org in Dex static client redirectURIs.

Environment variables:
  ORG              Org/realm name (required)
  BASE_DOMAIN      Portal base domain (default: portal.localhost)
  NAMESPACE        Kubernetes namespace for Dex (default: platform-mesh-system)
  DEX_CLIENT_ID    Dex static client id (default: keycloak-broker)
  ROLLOUT_TIMEOUT  Dex rollout wait timeout (default: 120s)
EOF
}

if [[ -z "$ORG" ]]; then
  usage >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required but not installed" >&2
  exit 1
fi

if ! kubectl get configmap dex -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Dex ConfigMap not found in namespace $NAMESPACE" >&2
  exit 1
fi

REDIRECT_URI="https://${BASE_DOMAIN}:8443/keycloak/realms/${ORG}/broker/dex/endpoint"

TMP_CONFIG="$(mktemp)"
trap 'rm -f "$TMP_CONFIG"' EXIT

kubectl get configmap dex -n "$NAMESPACE" -o jsonpath='{.data.config\.yaml}' >"$TMP_CONFIG"

if [[ ! -s "$TMP_CONFIG" ]]; then
  echo "Dex config.yaml is empty or missing in ConfigMap dex" >&2
  exit 1
fi

if ! yq -e '.staticClients[] | select(.id == "'"$DEX_CLIENT_ID"'")' "$TMP_CONFIG" >/dev/null; then
  echo "Dex static client '$DEX_CLIENT_ID' not found in config" >&2
  exit 1
fi

changed=false
if yq -r '.staticClients[] | select(.id == "'"$DEX_CLIENT_ID"'") | .redirectURIs[]' "$TMP_CONFIG" | grep -Fxq "$REDIRECT_URI"; then
  echo "Redirect URI already registered for org '$ORG':"
  echo "  $REDIRECT_URI"
else
  yq -i '(.staticClients[] | select(.id == "'"$DEX_CLIENT_ID"'") | .redirectURIs) += ["'"$REDIRECT_URI"'"]' "$TMP_CONFIG"
  kubectl create configmap dex \
    --from-file=config.yaml="$TMP_CONFIG" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
  changed=true
  echo "Registered redirect URI for org '$ORG':"
  echo "  $REDIRECT_URI"
fi

if [[ "$changed" == true ]]; then
  echo "Restarting Dex to pick up config changes..."
  kubectl rollout restart deployment/dex -n "$NAMESPACE"
  kubectl rollout status deployment/dex -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"
else
  echo "No Dex restart required."
fi

echo "Done. Dex broker callback for org '$ORG' is active."
