#!/usr/bin/env bash
# Bootstrap script for platform-mesh production deployment.
# Run this once before applying the kustomize overlay to generate required secrets.
# All secrets are random and never hardcoded.

set -euo pipefail

NAMESPACE="${NAMESPACE:-platform-mesh-system}"

info() { echo "[INFO] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl not found"
command -v openssl >/dev/null 2>&1 || die "openssl not found"

info "Creating namespace ${NAMESPACE} (idempotent)"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Keycloak admin secret
# The infra chart only renders keycloak-admin when keycloak.operator.admin.password is set.
# In production, pre-create this secret here so the chart skips rendering it.
if kubectl get secret keycloak-admin -n "${NAMESPACE}" >/dev/null 2>&1; then
  info "Secret keycloak-admin already exists, skipping"
else
  KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -base64 32)
  KEYCLOAK_CLIENT_SECRET=$(openssl rand -base64 32)
  kubectl create secret generic keycloak-admin \
    -n "${NAMESPACE}" \
    --from-literal=username="keycloak-admin" \
    --from-literal=password="${KEYCLOAK_ADMIN_PASSWORD}" \
    --from-literal=secret="${KEYCLOAK_CLIENT_SECRET}"
  info "Created secret keycloak-admin"
fi

# Keycloak DB credentials (cnpg-keycloak-user + keycloak-db-credentials)
# The infra chart only renders these when keycloak.operator.db.password is set.
if kubectl get secret cnpg-keycloak-user -n "${NAMESPACE}" >/dev/null 2>&1; then
  info "Secret cnpg-keycloak-user already exists, skipping"
else
  KEYCLOAK_DB_PASSWORD=$(openssl rand -base64 32)
  kubectl create secret generic cnpg-keycloak-user \
    -n "${NAMESPACE}" \
    --from-literal=username="keycloak" \
    --from-literal=password="${KEYCLOAK_DB_PASSWORD}"
  kubectl create secret generic keycloak-db-credentials \
    -n "${NAMESPACE}" \
    --from-literal=username="keycloak" \
    --from-literal=password="${KEYCLOAK_DB_PASSWORD}"
  info "Created secrets cnpg-keycloak-user and keycloak-db-credentials"
fi

# OpenFGA DB credentials (cnpg-openfga-user + openfga-postgres-credentials)
# The infra chart only renders cnpg-openfga-user when cnpg.roles.keycloak.password is set.
if kubectl get secret cnpg-openfga-user -n "${NAMESPACE}" >/dev/null 2>&1; then
  info "Secret cnpg-openfga-user already exists, skipping"
else
  OPENFGA_DB_PASSWORD=$(openssl rand -base64 32)
  kubectl create secret generic cnpg-openfga-user \
    -n "${NAMESPACE}" \
    --from-literal=username="openfga" \
    --from-literal=password="${OPENFGA_DB_PASSWORD}"
  kubectl create secret generic openfga-postgres-credentials \
    -n "${NAMESPACE}" \
    --from-literal=password="${OPENFGA_DB_PASSWORD}" \
    --from-literal=postgres-password="${OPENFGA_DB_PASSWORD}"
  info "Created secrets cnpg-openfga-user and openfga-postgres-credentials"
fi

# OpenSearch credentials (used by search-operator via OPENSEARCH_URL / OPENSEARCH_USERNAME / OPENSEARCH_PASSWORD env vars)
# These are not auto-generated — OpenSearch must be provisioned separately.
# Set OPENSEARCH_URL, OPENSEARCH_USERNAME, OPENSEARCH_PASSWORD before running this script
# or create the secret manually afterwards.
if kubectl get secret search-operator-opensearch -n "${NAMESPACE}" >/dev/null 2>&1; then
  info "Secret search-operator-opensearch already exists, skipping"
elif [[ -n "${OPENSEARCH_URL:-}" && -n "${OPENSEARCH_USERNAME:-}" && -n "${OPENSEARCH_PASSWORD:-}" ]]; then
  kubectl create secret generic search-operator-opensearch \
    -n "${NAMESPACE}" \
    --from-literal=url="${OPENSEARCH_URL}" \
    --from-literal=username="${OPENSEARCH_USERNAME}" \
    --from-literal=password="${OPENSEARCH_PASSWORD}"
  info "Created secret search-operator-opensearch"
else
  info "Skipping search-operator-opensearch secret (OPENSEARCH_URL/USERNAME/PASSWORD not set)"
  info "  Create it manually: kubectl create secret generic search-operator-opensearch -n ${NAMESPACE} --from-literal=url=<url> --from-literal=username=<user> --from-literal=password=<pass>"
fi

info ""
info "Bootstrap complete. Before applying the kustomize overlay, ensure you have:"
info "  1. Set spec.exposure.baseDomain in platform-mesh.yaml to your production domain"
info "  2. Configured SMTP server args in default-profile.yaml (search for REQUIRED: SMTP)"
info "  3. Set the Keycloak hostname in default-profile.yaml (search for REQUIRED: Keycloak URL)"
info "  4. Created the search-operator-opensearch secret (see above)"
info ""
info "Apply with: kubectl kustomize production-setup/kustomize/overlays/platform-mesh-resource | kubectl apply -f -"
