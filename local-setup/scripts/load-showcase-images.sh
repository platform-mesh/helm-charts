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

# Build terminal docker image (for terminal pods)
echo "Building terminal image..."
docker build \
    -t terminal:local \
    -f "${TERMINAL_CONTROLLER_MANAGER_DIR}/images/terminal/Dockerfile" \
    "${TERMINAL_CONTROLLER_MANAGER_DIR}/images/terminal"

echo "Loading terminal image into kind cluster..."
kind load docker-image terminal:local -n platform-mesh