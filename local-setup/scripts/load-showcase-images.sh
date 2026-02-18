#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
# This script is sourced by start.sh to load showcase Docker images into the Kind cluster.
# Used for loading local event/showcase images that demonstrate platform capabilities.

# Clone or update generic-resource-ui
GENERIC_RESOURCE_UI_DIR="${SCRIPT_DIR}/../src/generic-resource-ui"
GENERIC_RESOURCE_UI_REPO="https://github.com/platform-mesh/generic-resource-ui.git"
GENERIC_RESOURCE_UI_BRANCH="main"

if [ ! -d "${GENERIC_RESOURCE_UI_DIR}" ]; then
    echo "Cloning generic-resource-ui..."
    mkdir -p "${SCRIPT_DIR}/../src"
    git clone -b "${GENERIC_RESOURCE_UI_BRANCH}" "${GENERIC_RESOURCE_UI_REPO}" "${GENERIC_RESOURCE_UI_DIR}"
else
    echo "Updating generic-resource-ui..."
    cd "${GENERIC_RESOURCE_UI_DIR}"
    git fetch origin
    git checkout "${GENERIC_RESOURCE_UI_BRANCH}"
    git pull origin "${GENERIC_RESOURCE_UI_BRANCH}"
    cd - > /dev/null
fi

# Build generic-resource-ui docker image
echo "Building generic-resource-ui image..."
docker build \
    -t generic-resource-ui:local \
    "${GENERIC_RESOURCE_UI_DIR}"

echo "Loading generic-resource-ui image into kind cluster..."
kind load docker-image generic-resource-ui:local -n platform-mesh

# Restart generic-resource-ui deployment if it exists
if kubectl get deployment generic-resource-ui -n platform-mesh-system &>/dev/null; then
    echo "Restarting generic-resource-ui deployment..."
    kubectl rollout restart deployment/generic-resource-ui -n platform-mesh-system
fi

# Clone or update terminal-controller-manager
TERMINAL_CONTROLLER_MANAGER_DIR="${SCRIPT_DIR}/../src/terminal-controller-manager"
TERMINAL_CONTROLLER_MANAGER_REPO="https://github.com/platform-mesh/terminal-controller-manager.git"
TERMINAL_CONTROLLER_MANAGER_BRANCH="feature/phase-1-core-controller"

if [ ! -d "${TERMINAL_CONTROLLER_MANAGER_DIR}" ]; then
    echo "Cloning terminal-controller-manager..."
    mkdir -p "${SCRIPT_DIR}/../src"
    git clone -b "${TERMINAL_CONTROLLER_MANAGER_BRANCH}" "${TERMINAL_CONTROLLER_MANAGER_REPO}" "${TERMINAL_CONTROLLER_MANAGER_DIR}"
else
    echo "Updating terminal-controller-manager..."
    cd "${TERMINAL_CONTROLLER_MANAGER_DIR}"
    git fetch origin
    git checkout "${TERMINAL_CONTROLLER_MANAGER_BRANCH}"
    git pull origin "${TERMINAL_CONTROLLER_MANAGER_BRANCH}"
    cd - > /dev/null
fi

# Build terminal-controller-manager docker image
echo "Building terminal-controller-manager image..."
docker build \
    -t terminal-controller-manager:local \
    "${TERMINAL_CONTROLLER_MANAGER_DIR}"

echo "Loading terminal-controller-manager image into kind cluster..."
kind load docker-image terminal-controller-manager:local -n platform-mesh

# Restart terminal-controller-manager deployment if it exists
if kubectl get deployment terminal-controller-manager -n platform-mesh-system &>/dev/null; then
    echo "Restarting terminal-controller-manager deployment..."
    kubectl rollout restart deployment/terminal-controller-manager -n platform-mesh-system
fi

# Build terminal docker image (for terminal pods)
echo "Building terminal image..."
docker build \
    -t terminal:local \
    -f "${TERMINAL_CONTROLLER_MANAGER_DIR}/images/terminal/Dockerfile" \
    "${TERMINAL_CONTROLLER_MANAGER_DIR}/images/terminal"

echo "Loading terminal image into kind cluster..."
kind load docker-image terminal:local -n platform-mesh

# Clone or update portal
PORTAL_DIR="${SCRIPT_DIR}/../src/portal"
PORTAL_REPO="https://github.com/platform-mesh/portal.git"
PORTAL_BRANCH="feat/terminal"

if [ ! -d "${PORTAL_DIR}" ]; then
    echo "Cloning portal..."
    mkdir -p "${SCRIPT_DIR}/../src"
    git clone -b "${PORTAL_BRANCH}" "${PORTAL_REPO}" "${PORTAL_DIR}"
else
    echo "Updating portal..."
    cd "${PORTAL_DIR}"
    git fetch origin
    git checkout "${PORTAL_BRANCH}"
    git pull origin "${PORTAL_BRANCH}"
    cd - > /dev/null
fi

# Get the current portal image tag from the cluster
PORTAL_IMAGE_TAG=$(kubectl get deployment portal -n platform-mesh-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | cut -d':' -f2)
if [ -z "${PORTAL_IMAGE_TAG}" ]; then
    PORTAL_IMAGE_TAG="local"
fi

# Build portal docker image
echo "Building portal image with tag ${PORTAL_IMAGE_TAG}..."
docker build \
    -t "ghcr.io/platform-mesh/portal:${PORTAL_IMAGE_TAG}" \
    "${PORTAL_DIR}"

echo "Loading portal image into kind cluster..."
kind load docker-image "ghcr.io/platform-mesh/portal:${PORTAL_IMAGE_TAG}" -n platform-mesh

# Restart portal deployment if it exists
if kubectl get deployment portal -n platform-mesh-system &>/dev/null; then
    echo "Restarting portal deployment..."
    kubectl rollout restart deployment/portal -n platform-mesh-system
fi
