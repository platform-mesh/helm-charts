#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../backup/openfga}"
FGA_SERVER_URL="${FGA_SERVER_URL:-http://localhost:8080}"

STORES_FILE="$BACKUP_DIR/store-list.json"
if [[ ! -f "$STORES_FILE" ]]; then
    echo "Error: $STORES_FILE not found. Run fga_backup.sh to generate it." >&2
    exit 1
fi

STORES=$(jq -r '.stores[] | "\(.id) \(.name)"' "$STORES_FILE")
if [[ -z "$STORES" ]]; then
    echo "No stores found in $STORES_FILE"
    exit 0
fi

while IFS=' ' read -r store_id store_name; do
    echo "  Exporting store: ${store_name} (${store_id})"
    STORE_DIR="$BACKUP_DIR/stores/${store_name}"
    mkdir -p "$STORE_DIR"

    fga model get --store-id "$store_id" --server-url "$FGA_SERVER_URL" \
        > "$STORE_DIR/authorization-model.json"

    fga tuple read --store-id "$store_id" --server-url "$FGA_SERVER_URL" \
        > "$STORE_DIR/tuples.json"

    echo "  Saved to $STORE_DIR"
done <<< "$STORES"
