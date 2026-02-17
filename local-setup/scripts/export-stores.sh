#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_LIST="$SCRIPT_DIR/../backup/fga/store-list.json"
OUTPUT_DIR="$SCRIPT_DIR/../backup/fga"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Read each store from the JSON and export it
jq -r '.stores[] | "\(.id) \(.name)"' "$STORE_LIST" | while read -r STORE_ID STORE_NAME; do
    echo "Exporting store: $STORE_NAME (ID: $STORE_ID)"
    fga store export --store-id="$STORE_ID" > "$OUTPUT_DIR/$STORE_NAME.yaml"
done

echo "Done exporting all stores."