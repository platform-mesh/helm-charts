#!/usr/bin/env bash
# Create durable test data for pre-migration snapshots (no cleanup).
#
# Follows the production Organization Onboarding procedure:
#   1. Grant RBAC to creator user in root:orgs
#   2. Create org Account CR as that user (impersonation so creator identity is set correctly)
#   3. Revoke RBAC
#   4. Create sub-accounts and HTTPBin resources
#
# Creates per org:
#   - org Account (type: org) in root:orgs
#   - account1 (type: account) in root:orgs:<org>
#   - account2 (type: account, sub-account) in root:orgs:<org>:<account1>
#   - HTTPBin in account1 and account2 workspaces
#
# Usage:
#   docs/migration-0.4/create-test-data.sh
#   ORG_A=acme ORG_B=corp docs/migration-0.4/create-test-data.sh
#
# Environment:
#   ORG_A, ORG_B            — org names (defaults: test-org-alpha, test-org-beta)
#   RUN_ID                  — suffix for resource names (default: random hex)
#   CREATOR_USER            — OIDC user email to set as org creator (default: username@sap.com)
#   CREATOR_PASSWORD        — password to set for creator in each org realm (default: MyPass1234)
#   INVITE_USER             — user email to invite as member in each account (default: testuser@email.com)
#   KEYCLOAK_URL            — Keycloak base URL (default: https://portal.localhost:8443/keycloak)
#   KEYCLOAK_ADMIN_USER     — Keycloak admin username (default: keycloak-admin)
#   KEYCLOAK_ADMIN_PASSWORD — Keycloak admin password (default: read from keycloak-admin secret)
#   IAM_BASE_URL            — portal base URL for IAM GraphQL (default: https://portal.localhost:8443)
#   KUBECONFIG_KCP          — KCP admin kubeconfig (default: .secret/kcp/admin.kubeconfig)
#   KCP_URL                 — KCP server base URL (derived from kubeconfig if unset)
#   ACCOUNT_READY_TIMEOUT   — seconds to wait for account readiness (default: 180)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

KUBECONFIG_KCP="${KUBECONFIG_KCP:-.secret/kcp/admin.kubeconfig}"
if [[ ! -f "$KUBECONFIG_KCP" ]]; then
  echo "Error: KCP admin kubeconfig not found at $KUBECONFIG_KCP" >&2
  exit 1
fi

_raw_server=$(kubectl --kubeconfig="$KUBECONFIG_KCP" config view \
  --minify --output='jsonpath={.clusters[0].cluster.server}')
KCP_URL="${KCP_URL:-${_raw_server%/clusters*}}"

ORG_A="${ORG_A:-test-org-alpha}"
ORG_B="${ORG_B:-test-org-beta}"
RUN_ID="${RUN_ID:-$(openssl rand -hex 4)}"
CREATOR_USER="${CREATOR_USER:-username@sap.com}"
CREATOR_PASSWORD="${CREATOR_PASSWORD:-MyPass1234}"
INVITE_USER="${INVITE_USER:-testuser@email.com}"
ACCOUNT_READY_TIMEOUT="${ACCOUNT_READY_TIMEOUT:-180}"

KEYCLOAK_URL="${KEYCLOAK_URL:-https://portal.localhost:8443/keycloak}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-keycloak-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-$(kubectl get secret -n platform-mesh-system keycloak-admin -o jsonpath='{.data.secret}' | base64 -d)}"
IAM_BASE_URL="${IAM_BASE_URL:-https://portal.localhost:8443}"

ACCT1="test-acct1-${RUN_ID}"
ACCT2="test-acct2-${RUN_ID}"
NS="test-data-${RUN_ID}"
HTTPBIN="test-httpbin-${RUN_ID}"

# Safe name for RBAC binding (replace @ and . with -)
CREATOR_BINDING="${CREATOR_USER//[@.]/-}-org-creator"

KC="kubectl --kubeconfig=$KUBECONFIG_KCP"

kcp() {
  local workspace="$1"; shift
  $KC --server "${KCP_URL}/clusters/${workspace}" "$@"
}

kcp_as() {
  local workspace="$1"; local user="$2"; shift 2
  $KC --server "${KCP_URL}/clusters/${workspace}" --as="$user" "$@"
}

keycloak_admin_token() {
  curl -sk \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" | jq -r '.access_token'
}

keycloak_upsert_user() {
  local realm="$1"
  local token; token=$(keycloak_admin_token)
  local user_id; user_id=$(curl -sk -H "Authorization: Bearer $token" \
    "${KEYCLOAK_URL}/admin/realms/${realm}/users?username=${CREATOR_USER//@/%40}" | \
    jq -r '.[0].id // empty')
  if [[ -z "$user_id" ]]; then
    curl -sk -X POST \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"${CREATOR_USER}\",\"email\":\"${CREATOR_USER}\",\"firstName\":\"Test\",\"lastName\":\"User\",\"enabled\":true,\"emailVerified\":true,\"requiredActions\":[]}" \
      "${KEYCLOAK_URL}/admin/realms/${realm}/users"
    user_id=$(curl -sk -H "Authorization: Bearer $token" \
      "${KEYCLOAK_URL}/admin/realms/${realm}/users?username=${CREATOR_USER//@/%40}" | \
      jq -r '.[0].id // empty')
  fi
  curl -sk -X PUT \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"password\",\"value\":\"${CREATOR_PASSWORD}\",\"temporary\":false}" \
    "${KEYCLOAK_URL}/admin/realms/${realm}/users/${user_id}/reset-password"
  curl -sk -X PUT \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"firstName":"Test","lastName":"User","emailVerified":true,"requiredActions":[]}' \
    "${KEYCLOAK_URL}/admin/realms/${realm}/users/${user_id}"
}

set_creator_password_in_org_realm() {
  local realm="$1"
  echo "  setting ${CREATOR_USER} password in Keycloak realm ${realm}"
  keycloak_upsert_user "$realm"
  echo "  password set for ${CREATOR_USER} in realm ${realm}"
}

# invite_user_as_member <org_name> <account_name> [account_path]
# Grants INVITE_USER the "member" role on the given Account via the IAM GraphQL API.
# The token is obtained as CREATOR_USER (the org owner) from the org's portal client,
# since the IAM KCP middleware validates the token against KCP using that client's azp.
# account_path defaults to root:orgs:<org_name> (pass explicitly for sub-accounts).
invite_user_as_member() {
  local org_name="$1"
  local account_name="$2"
  local account_path="${3:-root:orgs:${org_name}}"
  echo "  inviting ${INVITE_USER} as member of ${account_name} in org ${org_name}"

  local admin_token; admin_token=$(curl -sk \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

  # The portal client in the org realm is a confidential client whose clientId is a UUID,
  # created by the security-operator at org init time.
  local portal_client_id; portal_client_id=$(curl -sk \
    -H "Authorization: Bearer ${admin_token}" \
    "${KEYCLOAK_URL}/admin/realms/${org_name}/clients" | \
    jq -r '[.[] | select(
      (.clientId | test("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")) and
      (.publicClient == false)
    )] | .[0].id')
  if [[ -z "$portal_client_id" || "$portal_client_id" == "null" ]]; then
    echo "  WARNING: portal client not found in realm ${org_name}" >&2
    return
  fi

  # Enable direct access grants so we can do a password grant with this client
  local client_data; client_data=$(curl -sk \
    -H "Authorization: Bearer ${admin_token}" \
    "${KEYCLOAK_URL}/admin/realms/${org_name}/clients/${portal_client_id}")
  curl -sk -o /dev/null -X PUT \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d "$(echo "$client_data" | jq '.directAccessGrantsEnabled = true')" \
    "${KEYCLOAK_URL}/admin/realms/${org_name}/clients/${portal_client_id}"

  local client_secret; client_secret=$(curl -sk \
    -H "Authorization: Bearer ${admin_token}" \
    "${KEYCLOAK_URL}/admin/realms/${org_name}/clients/${portal_client_id}/client-secret" | \
    jq -r '.value')

  # Authenticate as CREATOR_USER (org owner) — azp=<portal-UUID> is what KCP trusts
  local id_token; id_token=$(curl -sk \
    -u "${portal_client_id}:${client_secret}" \
    -d "username=${CREATOR_USER}" \
    -d "password=${CREATOR_PASSWORD}" \
    -d "grant_type=password" \
    -d "scope=openid email profile" \
    "${KEYCLOAK_URL}/realms/${org_name}/protocol/openid-connect/token" | jq -r '.id_token')
  if [[ -z "$id_token" || "$id_token" == "null" ]]; then
    echo "  WARNING: failed to get ID token for ${CREATOR_USER} in realm ${org_name}" >&2
    return
  fi

  # IAM KCP middleware reads OrganizationName from the Host header subdomain
  local iam_url="${IAM_BASE_URL/portal.localhost/${org_name}.portal.localhost}/iam/graphql"

  local result; result=$(curl -sk -X POST \
    "${iam_url}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${id_token}" \
    -d "$(jq -cn \
      --arg accountPath "$account_path" \
      --arg account "$account_name" \
      --arg email "$INVITE_USER" \
      '{
        query: "mutation($context: ResourceContext!, $invites: [InviteInput!]) { assignRolesToUsers(context: $context, invites: $invites) { success assignedCount errors } }",
        variables: {
          context: {
            accountPath: $accountPath,
            group: "core.platform-mesh.io",
            kind: "Account",
            resource: { name: $account }
          },
          invites: [{ email: $email, roles: ["member"] }]
        }
      }')")

  if echo "$result" | jq -e '.errors' >/dev/null 2>&1; then
    echo "  WARNING: invite failed for ${INVITE_USER} on ${account_name}: $(echo "$result" | jq -r '.errors[0].message')" >&2
  else
    local count; count=$(echo "$result" | jq -r '.data.assignRolesToUsers.assignedCount // "0"')
    echo "  ${INVITE_USER} invited as member of ${account_name} (assigned: ${count})"
  fi
}

apply_manifest() {
  local workspace="$1"
  local manifest="$2"
  echo "$manifest" | kcp "$workspace" apply -f -
}

wait_account_ready() {
  local workspace="$1"
  local account="$2"
  echo "  waiting for account ${account} in ${workspace} ..."
  kcp "$workspace" wait \
    --for=condition=Ready \
    "--timeout=${ACCOUNT_READY_TIMEOUT}s" \
    "accounts.core.platform-mesh.io/${account}"
}

ensure_org() {
  local org="$1"
  echo "=== Ensuring org: ${org} ==="

  # Step 1: Grant creator user temporary admin access in root:orgs
  echo "  granting ${CREATOR_USER} cluster-admin in root:orgs"
  kcp "root:orgs" create clusterrolebinding "${CREATOR_BINDING}" \
    --clusterrole=cluster-admin \
    --user="${CREATOR_USER}" \
    --dry-run=client -o yaml | kcp "root:orgs" apply -f -

  # Step 2: Create org Account as the creator user (impersonation sets creator identity)
  echo "  creating Account ${org} as ${CREATOR_USER}"
  kcp_as "root:orgs" "$CREATOR_USER" apply -f - <<EOF
apiVersion: core.platform-mesh.io/v1alpha1
kind: Account
metadata:
  name: ${org}
spec:
  type: org
  displayName: ${org}
  creator: ${CREATOR_USER}
EOF

  wait_account_ready "root:orgs" "$org"

  # Step 3: Revoke temporary admin access
  echo "  revoking ${CREATOR_USER} cluster-admin from root:orgs"
  kcp "root:orgs" delete clusterrolebinding "${CREATOR_BINDING}" --ignore-not-found

  # Step 4: Set known password in the org's Keycloak realm (initializer creates user with temp password)
  set_creator_password_in_org_realm "$org"

  # Step 5: Invite creator as member in the org portal
  invite_user_as_member "$org" "$org" "root:orgs"
}

ensure_account() {
  local workspace="$1"
  local account="$2"
  echo "  ensuring account ${account} in ${workspace}"
  apply_manifest "$workspace" "$(cat <<EOF
apiVersion: core.platform-mesh.io/v1alpha1
kind: Account
metadata:
  name: ${account}
spec:
  type: account
  displayName: ${account}
EOF
)"
  wait_account_ready "$workspace" "$account"
}

ensure_provider_enabled() {
  local workspace="$1"
  echo "  waiting for ABC MSP Provider (orchestrate.platform-mesh.io) in ${workspace}"
  # The platform-mesh operator auto-creates this APIBinding via extraDefaultAPIBindings.
  # Wait for it to become Ready before creating resources that depend on it.
  local deadline=$(( $(date +%s) + 60 ))
  while true; do
    local ready
    ready=$(kcp "$workspace" get apibindings \
      -o jsonpath='{.items[?(@.spec.reference.export.name=="orchestrate.platform-mesh.io")].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [[ "$ready" == "True" ]]; then
      echo "  ABC MSP Provider ready in ${workspace}"
      return
    fi
    if (( $(date +%s) >= deadline )); then
      echo "  WARNING: ABC MSP Provider not ready in ${workspace} after 60s" >&2
      return
    fi
    sleep 3
  done
}

ensure_httpbin() {
  local workspace="$1"
  local ns="$2"
  local name="$3"
  echo "  ensuring namespace ${ns} and httpbin ${name} in ${workspace}"

  apply_manifest "$workspace" "$(cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
EOF
)"

  apply_manifest "$workspace" "$(cat <<EOF
apiVersion: orchestrate.platform-mesh.io/v1alpha1
kind: HttpBin
metadata:
  name: ${name}
  namespace: ${ns}
EOF
)"

  echo "  waiting for httpbin ${name} in ${workspace} ..."
  kcp "$workspace" wait \
    --for=condition=Ready \
    --timeout=120s \
    -n "$ns" \
    "httpbins.orchestrate.platform-mesh.io/${name}"
}

echo "=== Ensuring ${CREATOR_USER} in Keycloak welcome realm ==="
keycloak_upsert_user "welcome"
echo "  ${CREATOR_USER} ready in welcome realm"

SUMMARY=()

for ORG in "$ORG_A" "$ORG_B"; do
  ensure_org "$ORG"

  echo "=== Org ${ORG}: account1 ==="
  ensure_account "root:orgs:${ORG}" "$ACCT1"
  invite_user_as_member "$ORG" "$ACCT1"
  ensure_provider_enabled "root:orgs:${ORG}:${ACCT1}"
  ensure_httpbin "root:orgs:${ORG}:${ACCT1}" "$NS" "$HTTPBIN"
  SUMMARY+=("${ORG}  ${ACCT1}  root:orgs:${ORG}:${ACCT1}  ${HTTPBIN}")

  echo "=== Org ${ORG}: account2 (sub-account of ${ACCT1}) ==="
  ensure_account "root:orgs:${ORG}:${ACCT1}" "$ACCT2"
  invite_user_as_member "$ORG" "$ACCT2" "root:orgs:${ORG}:${ACCT1}"
  ensure_provider_enabled "root:orgs:${ORG}:${ACCT1}:${ACCT2}"
  ensure_httpbin "root:orgs:${ORG}:${ACCT1}:${ACCT2}" "$NS" "$HTTPBIN"
  SUMMARY+=("${ORG}  ${ACCT1}:${ACCT2}  root:orgs:${ORG}:${ACCT1}:${ACCT2}  ${HTTPBIN}")
done

echo ""
echo "=== Test data summary ==="
printf "%-24s  %-36s  %-52s  %s\n" "Org" "Account path" "Workspace" "HTTPBin"
printf "%-24s  %-36s  %-52s  %s\n" "---" "------------" "---------" "-------"
for row in "${SUMMARY[@]}"; do
  IFS='  ' read -r org acct ws hb <<< "$row"
  printf "%-24s  %-36s  %-52s  %s\n" "$org" "$acct" "$ws" "$hb"
done
