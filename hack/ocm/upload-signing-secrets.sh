#!/usr/bin/env bash
set -euo pipefail

# Uploads per-component signing secrets to GitHub.
# Requires: gh CLI authenticated with sufficient permissions.
#
# Usage:
#   ./hack/upload-signing-secrets.sh              # upload all component secrets
#   ./hack/upload-signing-secrets.sh my-component  # upload a single component's secrets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SECRETS_DIR="${REPO_ROOT}/.secrets"
ORG="platform-mesh"

COMPONENTS=(
  account-operator
  example-httpbin-operator
  extension-manager-operator
  generic-resource-ui
  helm-charts
  iam-service
  iam-ui
  kcp-migration-operator
  kubernetes-graphql-gateway
  marketplace-ui
  ocm
  platform-mesh-operator
  portal
  rebac-authz-webhook
  security-operator
  virtual-workspaces
  terminal-controller-manager
)

upload_component_secrets() {
  local name="$1"
  local priv="${SECRETS_DIR}/${name}.priv"
  local cert="${SECRETS_DIR}/${name}.cert"
  local repo="${ORG}/${name}"

  if [[ ! -f "${priv}" ]]; then
    echo "  SKIP: ${priv} not found" >&2
    return 1
  fi
  if [[ ! -f "${cert}" ]]; then
    echo "  SKIP: ${cert} not found" >&2
    return 1
  fi

  echo "==> ${repo}"
  gh secret set OCM_SIGNING_PRIVATE_KEY --repo "${repo}" < "${priv}"
  gh secret set OCM_SIGNING_CERT --repo "${repo}" < "${cert}"
  echo "    done"
}

main() {
  if [[ $# -eq 1 ]]; then
    upload_component_secrets "$1"
    exit 0
  fi

  echo "Uploading signing secrets to GitHub"
  echo "===================================="
  echo ""

  local failed=0
  for component in "${COMPONENTS[@]}"; do
    upload_component_secrets "${component}" || ((failed++))
  done

  echo ""
  if [[ ${failed} -gt 0 ]]; then
    echo "Done with ${failed} failure(s)."
    exit 1
  fi
  echo "Done. All secrets uploaded."
}

main "$@"
