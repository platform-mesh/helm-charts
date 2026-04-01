#!/usr/bin/env bash
set -euo pipefail

# Generates per-component signing certificates signed by the CA.
# Requires the CA to exist (run ./hack/generate-signing-ca.sh first).
#
# Usage:
#   ./hack/generate-signing-keys.sh              # regenerate all component certs
#   ./hack/generate-signing-keys.sh my-component  # generate a single component cert
#
# Output:
#   .secrets/<name>.priv   Component private key
#   .secrets/<name>.cert   Component certificate (signed by CA)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SECRETS_DIR="${REPO_ROOT}/.secrets"
CA_DIR="${SECRETS_DIR}/ca"
VALIDITY_DAYS=3650
CA_CN="platform-mesh"

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
)

generate_component_cert() {
  local name="$1"
  local cn="${name}.${CA_CN}"
  local tmp_csr
  tmp_csr="$(mktemp)"

  echo "==> Generating certificate for ${name} (CN=${cn})"

  # Make existing files writable if they exist
  chmod u+w "${SECRETS_DIR}/${name}.priv" "${SECRETS_DIR}/${name}.cert" 2>/dev/null || true

  # Generate key + CSR
  openssl req -newkey rsa:2048 -nodes \
    -keyout "${SECRETS_DIR}/${name}.priv" \
    -out "${tmp_csr}" \
    -subj "/CN=${cn}"

  # Sign with CA
  openssl x509 -req -days "${VALIDITY_DAYS}" \
    -in "${tmp_csr}" \
    -CA "${CA_DIR}/ca.cert" \
    -CAkey "${CA_DIR}/ca.priv" \
    -CAcreateserial \
    -out "${SECRETS_DIR}/${name}.cert" \
    -extfile <(printf 'extendedKeyUsage=codeSigning\nbasicConstraints=critical,CA:FALSE')

  chmod 400 "${SECRETS_DIR}/${name}.priv" "${SECRETS_DIR}/${name}.cert"
  rm -f "${tmp_csr}"

  echo "    ${name}.cert"
  echo "    ${name}.priv"
}

main() {
  if [[ ! -f "${CA_DIR}/ca.priv" || ! -f "${CA_DIR}/ca.cert" ]]; then
    echo "Error: CA not found at ${CA_DIR}." >&2
    echo "Run ./hack/generate-signing-ca.sh first." >&2
    exit 1
  fi

  if [[ $# -eq 1 ]]; then
    generate_component_cert "$1"
    echo ""
    echo "Done. Remember to update the GitHub secret for this component."
    exit 0
  fi

  echo "Generating component signing certificates"
  echo "=========================================="
  echo ""

  for component in "${COMPONENTS[@]}"; do
    generate_component_cert "${component}"
  done

  echo ""
  echo "Done. Next steps:"
  echo "  1. Update GitHub secrets with the new private keys (.secrets/<name>.priv)"
  echo "  2. Re-sign all published component versions via CI"
}

main "$@"
