#!/bin/bash
set -euo pipefail

# Script to patch AccountInfo objects with OIDC configuration
# and URL hostname for all workspaces under :root:orgs

ISSUER_BASE_URL="${ISSUER_BASE_URL:-https://portal.localhost:8443/keycloak/realms}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://portal.localhost:8443/keycloak}"
KEYCLOAK_USER="${KEYCLOAK_USER:-keycloak-admin}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
OLD_HOST="${OLD_HOST:-kcp.api.portal.dev.local}"
NEW_HOST="${NEW_HOST:-localhost}"

# Get Keycloak admin token
get_admin_token() {
    curl -sk -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${KEYCLOAK_USER}" \
        -d "password=${KEYCLOAK_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token'
}

# Get client ID (the actual UUID) for a client name in a realm
get_client_id() {
    local token="$1"
    local realm="$2"
    local client_name="$3"

    curl -sk -X GET "${KEYCLOAK_URL}/admin/realms/${realm}/clients?clientId=${client_name}" \
        -H "Authorization: Bearer ${token}" | jq -r '.[0].clientId // empty'
}

# Recursive function to process workspaces and patch AccountInfo
# Arguments: $1 = workspace path (e.g., :root:orgs:default)
process_workspace() {
    local ws_path="$1"
    local indent="$2"

    echo "${indent}Processing workspace: $ws_path"

    # Navigate to the workspace
    kubectl ws "$ws_path"

    # Extract realm name from the workspace path (last segment after :root:orgs:)
    # e.g., :root:orgs:default -> default, :root:orgs:default:testaccount -> testaccount
    local realm_name
    realm_name=$(echo "$ws_path" | sed 's/.*:orgs://' | tr ':' '-')
    # For nested paths like default:testaccount, use the full path with dashes
    # But for Keycloak realm lookup, we need to determine the actual realm
    local keycloak_realm
    keycloak_realm=$(echo "$ws_path" | sed 's/.*:orgs://' | sed 's/:.*$//')

    # Check if AccountInfo named "account" exists in this workspace
    if kubectl get accountinfo account &>/dev/null; then
        echo "${indent}  Found AccountInfo 'account', patching..."

        # Get current URLs and replace hostname
        local account_url org_url parent_url
        account_url=$(kubectl get accountinfo account -o jsonpath='{.spec.account.url}' 2>/dev/null || echo "")
        org_url=$(kubectl get accountinfo account -o jsonpath='{.spec.organization.url}' 2>/dev/null || echo "")
        parent_url=$(kubectl get accountinfo account -o jsonpath='{.spec.parentAccount.url}' 2>/dev/null || echo "")

        echo "${indent}  Current account.url: '$account_url'"
        echo "${indent}  Current organization.url: '$org_url'"
        echo "${indent}  Current parentAccount.url: '$parent_url'"

        # Patch each URL field individually using JSON Patch for precise updates
        # This avoids issues with merge patch and empty values

        if [[ -n "$account_url" && "$account_url" == *"$OLD_HOST"* ]]; then
            local new_account_url
            new_account_url="${account_url//$OLD_HOST/$NEW_HOST}"
            echo "${indent}  Patching account.url: $account_url -> $new_account_url"
            kubectl patch accountinfo account --type=json \
                -p "[{\"op\": \"replace\", \"path\": \"/spec/account/url\", \"value\": \"${new_account_url}\"}]"
        fi

        if [[ -n "$org_url" && "$org_url" == *"$OLD_HOST"* ]]; then
            local new_org_url
            new_org_url="${org_url//$OLD_HOST/$NEW_HOST}"
            echo "${indent}  Patching organization.url: $org_url -> $new_org_url"
            kubectl patch accountinfo account --type=json \
                -p "[{\"op\": \"replace\", \"path\": \"/spec/organization/url\", \"value\": \"${new_org_url}\"}]"
        fi

        if [[ -n "$parent_url" && "$parent_url" == *"$OLD_HOST"* ]]; then
            local new_parent_url
            new_parent_url="${parent_url//$OLD_HOST/$NEW_HOST}"
            echo "${indent}  Patching parentAccount.url: $parent_url -> $new_parent_url"
            kubectl patch accountinfo account --type=json \
                -p "[{\"op\": \"replace\", \"path\": \"/spec/parentAccount/url\", \"value\": \"${new_parent_url}\"}]"
        fi

        # Fetch client IDs from Keycloak using the top-level realm
        echo "${indent}  Fetching client IDs from Keycloak for realm: $keycloak_realm"
        local default_client_id kubectl_client_id
        default_client_id=$(get_client_id "$ADMIN_TOKEN" "$keycloak_realm" "default")
        kubectl_client_id=$(get_client_id "$ADMIN_TOKEN" "$keycloak_realm" "kubectl")

        if [[ -z "$default_client_id" ]]; then
            echo "${indent}  Warning: 'default' client not found in Keycloak realm $keycloak_realm, using 'default'"
            default_client_id="default"
        else
            echo "${indent}  Found default client ID: $default_client_id"
        fi

        if [[ -z "$kubectl_client_id" ]]; then
            echo "${indent}  Warning: 'kubectl' client not found in Keycloak realm $keycloak_realm, using 'kubectl'"
            kubectl_client_id="kubectl"
        else
            echo "${indent}  Found kubectl client ID: $kubectl_client_id"
        fi

        # Patch OIDC configuration using merge patch
        local oidc_patch
        oidc_patch=$(cat <<EOF
{
  "spec": {
    "oidc": {
      "clients": {
        "default": {
          "clientId": "${default_client_id}"
        },
        "kubectl": {
          "clientId": "${kubectl_client_id}"
        }
      },
      "issuerUrl": "${ISSUER_BASE_URL}/${keycloak_realm}"
    }
  }
}
EOF
)

        echo "${indent}  Patching OIDC configuration..."
        kubectl patch accountinfo account --type=merge -p "$oidc_patch"
        echo "${indent}  Successfully patched AccountInfo"
    else
        echo "${indent}  No AccountInfo 'account' found, skipping patch..."
    fi

    # Get child workspaces and process them recursively
    local children
    children=$(kubectl get workspaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$children" ]]; then
        echo "${indent}  Found child workspaces: $children"
        for child in $children; do
            process_workspace "${ws_path}:${child}" "${indent}  "
        done
    fi
}

echo "=== Fetching Keycloak admin token ==="
ADMIN_TOKEN=$(get_admin_token)
if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
    echo "Error: Failed to get Keycloak admin token"
    exit 1
fi
echo "Successfully obtained admin token"

# Start recursive processing from :root:orgs
echo "=== Starting recursive AccountInfo patching from :root:orgs ==="

# First, get all top-level orgs
kubectl ws :root:orgs
TOP_LEVEL_ORGS=$(kubectl get workspaces -o jsonpath='{.items[*].metadata.name}')

if [[ -z "$TOP_LEVEL_ORGS" ]]; then
    echo "No workspaces found under :root:orgs"
    exit 0
fi

echo "Found top-level orgs: $TOP_LEVEL_ORGS"

for org in $TOP_LEVEL_ORGS; do
    process_workspace ":root:orgs:${org}" ""
done

# Return to root workspace
kubectl ws :root

echo "=== Done patching all AccountInfo objects recursively (OIDC and URL) ==="
