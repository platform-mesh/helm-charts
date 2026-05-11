#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: $0 <keycloak-version>}"
OUT_DIR="charts/keycloak-operator/crds"
BASE_URL="https://raw.githubusercontent.com/k8s-operatorhub/community-operators/main/operators/keycloak-operator/${VERSION}/manifests"

curl -sLf "${BASE_URL}/keycloaks.k8s.keycloak.org-v1.crd.yml" -o "${OUT_DIR}/keycloaks.k8s.keycloak.org-v1.yml"
curl -sLf "${BASE_URL}/keycloakrealmimports.k8s.keycloak.org-v1.crd.yml" -o "${OUT_DIR}/keycloakrealmimports.k8s.keycloak.org-v1.yml"
