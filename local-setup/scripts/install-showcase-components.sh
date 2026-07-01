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

    # Patch the terminal.platform-mesh.io APIExport's permission claim on
    # accountinfos to reference the current core.platform-mesh.io identityHash.
    # The operator ships a hardcoded stale hash which never matches a fresh
    # install, so the accountinfos claim never surfaces on the terminal
    # virtual workspace and the terminal-controller-manager cannot get
    # AccountInfo → terminals hang forever in "starting terminal...".
    KCP_SERVER="https://kcp.api.portal.localhost:8443/clusters/root:platform-mesh-system"
    CORE_HASH=$(KUBECONFIG="${KCP_ADMIN_KUBECONFIG}" kubectl --server="${KCP_SERVER}" \
      get apiexport core.platform-mesh.io -o jsonpath='{.status.identityHash}' 2>/dev/null)
    if [ -n "${CORE_HASH}" ]; then
      echo "Patching terminal.platform-mesh.io APIExport accountinfos identityHash to ${CORE_HASH}..."
      KUBECONFIG="${KCP_ADMIN_KUBECONFIG}" kubectl --server="${KCP_SERVER}" \
        patch apiexport terminal.platform-mesh.io --type=json \
        -p="[{\"op\":\"replace\",\"path\":\"/spec/permissionClaims/0/identityHash\",\"value\":\"${CORE_HASH}\"}]" \
        || echo "Warning: failed to patch terminal APIExport identityHash"
    else
      echo "Warning: could not read core.platform-mesh.io identityHash; skipping terminal APIExport patch"
    fi
else
    echo "Warning: KCP admin kubeconfig not found, skipping KCP resource application."
fi

echo "Showcase components installed successfully!"
