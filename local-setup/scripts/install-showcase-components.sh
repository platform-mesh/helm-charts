#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
# This script is sourced by start.sh to install showcase components after platform-mesh is ready.
# It deploys the helm charts for the showcase components that were loaded by load-showcase-images.sh.

# Ensure we're using the kind cluster context, not KCP
KIND_CONTEXT="kind-platform-mesh"
echo "Switching to kind cluster context: ${KIND_CONTEXT}..."
kubectl config use-context "${KIND_CONTEXT}"

# Update helm dependencies for generic-resource-ui
echo "Updating helm dependencies for generic-resource-ui..."
helm dependency update "${SCRIPT_DIR}/../../charts/generic-resource-ui"

# Deploy generic-resource-ui via helm
echo "Deploying generic-resource-ui..."
helm upgrade -i generic-resource-ui "${SCRIPT_DIR}/../../charts/generic-resource-ui" \
  --namespace platform-mesh-system --create-namespace \
  -f "${SCRIPT_DIR}/../showcase/deployments/generic-resource-ui/values.yaml"

# Update helm dependencies for terminal-controller-manager
echo "Updating helm dependencies for terminal-controller-manager..."
helm dependency update "${SCRIPT_DIR}/../../charts/terminal-controller-manager"

# Deploy terminal-controller-manager via helm
echo "Deploying terminal-controller-manager..."
helm upgrade -i terminal-controller-manager "${SCRIPT_DIR}/../../charts/terminal-controller-manager" \
  --namespace platform-mesh-system --create-namespace \
  -f "${SCRIPT_DIR}/../showcase/deployments/terminal-controller-manager/values.yaml"

# Apply KCP resources for showcase
KCP_ADMIN_KUBECONFIG="${SCRIPT_DIR}/../../.secret/kcp/admin.kubeconfig"
if [ -f "${KCP_ADMIN_KUBECONFIG}" ]; then
    echo "Applying showcase KCP resources to root:platform-mesh-system..."
    KUBECONFIG="${KCP_ADMIN_KUBECONFIG}" kubectl apply -k "${SCRIPT_DIR}/../showcase/kcp/root/platform-mesh-system" \
      --server="https://localhost:8443/clusters/root:platform-mesh-system"
else
    echo "Warning: KCP admin kubeconfig not found, skipping KCP resource application."
fi

echo "Showcase components installed successfully!"
