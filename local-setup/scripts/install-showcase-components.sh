#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
# Sourced by start.sh to install showcase components after platform-mesh is
# ready. terminal-controller-manager (helm chart + KCP APIExport/Schema +
# provider kubeconfig secret) is now handled by the platform-mesh-operator via
# the `feature-enable-terminal-controller-manager` feature toggle and the
# `terminal-controller-manager.enabled: true` profile entry. This script
# installs generic-resource-ui (not yet operator-managed) and applies the
# showcase-specific ContentConfigurations to KCP.

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

# Apply showcase ContentConfigurations to KCP.
KCP_ADMIN_KUBECONFIG="${SCRIPT_DIR}/../../.secret/kcp/admin.kubeconfig"
if [ -f "${KCP_ADMIN_KUBECONFIG}" ]; then
    echo "Applying showcase KCP resources to root:platform-mesh-system..."
    KUBECONFIG="${KCP_ADMIN_KUBECONFIG}" kubectl apply -k "${SCRIPT_DIR}/../showcase/kcp/root/platform-mesh-system" \
      --server="https://kcp.api.portal.localhost:8443/clusters/root:platform-mesh-system"
else
    echo "Warning: KCP admin kubeconfig not found, skipping KCP resource application."
fi

echo "Showcase components installed successfully!"
