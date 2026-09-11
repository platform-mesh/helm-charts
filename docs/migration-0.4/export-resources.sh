#!/usr/bin/env bash
set -euo pipefail

# Export all KCP and Kubernetes resources as YAML.
#
# Usage:
#   docs/migration-0.4/export-resources.sh <output-dir>
#
# Example:
#   docs/migration-0.4/export-resources.sh local-setup/backup/pre-migration-0.4

OUTDIR="${1:?Usage: $0 <output-dir>}"
KUBECONFIG_KCP="${KUBECONFIG_KCP:-.secret/kcp/admin.kubeconfig}"

if [[ ! -f "$KUBECONFIG_KCP" ]]; then
  echo "Error: KCP admin kubeconfig not found at $KUBECONFIG_KCP" >&2
  echo "Run 'local-setup/scripts/createKcpAdminKubeconfig.sh' first." >&2
  exit 1
fi

KC="kubectl --kubeconfig=$KUBECONFIG_KCP"

# Derive the base KCP server URL (strip any /clusters/... suffix so we can
# construct workspace-specific paths ourselves).
_raw_server=$(kubectl --kubeconfig="$KUBECONFIG_KCP" config view \
  --minify --output='jsonpath={.clusters[0].cluster.server}')
KCP_SERVER="${KCP_SERVER:-${_raw_server%/clusters*}}"
echo "KCP server: $KCP_SERVER"

kcp_get() {
  local ws="$1" resource="$2"
  $KC get "$resource" --server "${KCP_SERVER}/clusters/${ws}" -o yaml 2>/dev/null || true
}

kcp_api_resources() {
  local ws="$1"
  $KC api-resources --server "${KCP_SERVER}/clusters/${ws}" 2>/dev/null || true
}

discover_workspaces() {
  local parent="$1"
  echo "$parent"
  local children
  children=$($KC get workspace --server "${KCP_SERVER}/clusters/${parent}" \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null) || true
  for child in $children; do
    discover_workspaces "${parent}:${child}"
  done
}

has_items() {
  local yaml="$1"
  [[ -n "$yaml" ]] && echo "$yaml" | grep -q '^kind:' && ! echo "$yaml" | grep -q '^items: \[\]$'
}

KCP_RESOURCES=(
  apiexports.apis.kcp.io
  apiexportendpointslices.apis.kcp.io
  apiresourceschemas.apis.kcp.io
  apibindings.apis.kcp.io
  apiconversions.apis.kcp.io
  workspaces.tenancy.kcp.io
  workspacetypes.tenancy.kcp.io
  workspaceauthenticationconfigurations.tenancy.kcp.io
  logicalclusters.core.kcp.io
  shards.core.kcp.io
  clusterroles
  clusterrolebindings
  secrets
  accounts.core.platform-mesh.io
  accountinfos.core.platform-mesh.io
  identityproviderconfigurations.core.platform-mesh.io
  stores.core.platform-mesh.io
  authorizationmodels.core.platform-mesh.io
  invites.core.platform-mesh.io
  apiexportpolicies.core.platform-mesh.io
  httpbins.orchestrate.platform-mesh.io
  httpbindeployments.orchestrate.platform-mesh.io
  managedproviders.providers.platform-mesh.io
  clusteraccesses.gateway.platform-mesh.io
  contentconfigurations.ui.platform-mesh.io
  providermetadatas.ui.platform-mesh.io
)

K8S_RESOURCES=(
  helmreleases.helm.toolkit.fluxcd.io
  components.delivery.ocm.software
  resourcegraphdefinitions.kro.run
  platformmeshes.core.platform-mesh.io
  resources.delivery.ocm.software
  managedproviders.providers.platform-mesh.io
  clusteraccesses.gateway.platform-mesh.io
  contentconfigurations.ui.platform-mesh.io
  pods
  deployments
  secrets
  persistentvolumeclaims
  persistentvolumes
)

echo "=== Discovering KCP workspaces ==="
WORKSPACES=()
while IFS= read -r ws; do
  WORKSPACES+=("$ws")
done < <(discover_workspaces "root")

echo "Found ${#WORKSPACES[@]} workspaces:"
printf "  %s\n" "${WORKSPACES[@]}"

mkdir -p "$OUTDIR"

echo ""
echo "=== Exporting KCP resources ==="

for ws in "${WORKSPACES[@]}"; do
  ws_dir="$OUTDIR/kcp/${ws//:/_}"
  mkdir -p "$ws_dir"

  echo "--- Workspace: $ws ---"

  echo "  api-resources"
  kcp_api_resources "$ws" > "$ws_dir/api-resources.txt"

  for resource in "${KCP_RESOURCES[@]}"; do
    short="${resource%%.*}"
    result=$(kcp_get "$ws" "$resource")
    if has_items "$result"; then
      echo "  $short"
      echo "$result" > "$ws_dir/${short}.yaml"
    fi
  done
done

echo ""
echo "=== Exporting K8s resources ==="

K8S_DIR="$OUTDIR/k8s"
mkdir -p "$K8S_DIR"

for resource in "${K8S_RESOURCES[@]}"; do
  short="${resource%%.*}"
  echo "  $short"
  kubectl get "$resource" -A -o yaml > "$K8S_DIR/${short}.yaml" 2>/dev/null || true
done

kubectl get pods -n platform-mesh-system -o wide > "$K8S_DIR/pods.txt" 2>/dev/null || true
kubectl get helmrelease -A > "$K8S_DIR/helmrelease-status.txt" 2>/dev/null || true

echo ""
echo "=== Export complete ==="
echo "Output directory: $OUTDIR"
find "$OUTDIR" -type f | wc -l | xargs -I{} echo "Total files: {}"
