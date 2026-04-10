#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KCP_URL="${KCP_URL:-https://localhost:8443}"
ADMIN_KUBECONFIG="${ADMIN_KUBECONFIG:-$ROOT_DIR/.secret/kcp/admin.kubeconfig}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-30s}"

if [[ ! -f "$ADMIN_KUBECONFIG" ]]; then
  echo "Admin kubeconfig not found at $ADMIN_KUBECONFIG" >&2
  exit 1
fi

runtime_kubectl=(kubectl)
kcp_kubectl=(kubectl --kubeconfig "$ADMIN_KUBECONFIG")

workspace_exists() {
  local workspace_path="$1"
  local parent="${workspace_path%:*}"
  local name="${workspace_path##*:}"
  [[ "$("${kcp_kubectl[@]}" --server "$KCP_URL/clusters/${parent}" get workspace "$name" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Ready" ]]
}

wait_for_ready_resources() {
  local description="$1"
  shift

  local -a get_cmd=("$@")
  local -a wait_cmd=()
  local seen_get=false
  local skipped_resource_type=false
  for arg in "${get_cmd[@]}"; do
    if [[ "$arg" == "get" ]]; then
      wait_cmd+=("wait")
      seen_get=true
      continue
    fi
    if [[ "$seen_get" == true && "$skipped_resource_type" == false && "$arg" != -* ]]; then
      skipped_resource_type=true
      continue
    fi
    wait_cmd+=("$arg")
  done

  if [[ "$seen_get" == false ]]; then
    echo "Internal error: expected a kubectl get command for $description" >&2
    exit 1
  fi

  local -a resources=()
  while IFS= read -r resource; do
    [[ -n "$resource" ]] && resources+=("$resource")
  done < <("${get_cmd[@]}" -o name)

  if [[ ${#resources[@]} -eq 0 ]]; then
    echo "No resources found for: $description" >&2
    exit 1
  fi

  echo "Checking $description"
  for resource in "${resources[@]}"; do
    echo "  waiting for $resource"
    "${wait_cmd[@]}" --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True --timeout="$WAIT_TIMEOUT" "$resource" >/dev/null
  done
}

wait_for_ready_resources_if_present() {
  local description="$1"
  shift

  local -a get_cmd=("$@")
  local -a wait_cmd=()
  local seen_get=false
  local skipped_resource_type=false
  for arg in "${get_cmd[@]}"; do
    if [[ "$arg" == "get" ]]; then
      wait_cmd+=("wait")
      seen_get=true
      continue
    fi
    if [[ "$seen_get" == true && "$skipped_resource_type" == false && "$arg" != -* ]]; then
      skipped_resource_type=true
      continue
    fi
    wait_cmd+=("$arg")
  done

  if [[ "$seen_get" == false ]]; then
    echo "Internal error: expected a kubectl get command for $description" >&2
    exit 1
  fi

  local -a resources=()
  while IFS= read -r resource; do
    [[ -n "$resource" ]] && resources+=("$resource")
  done < <("${get_cmd[@]}" -o name)

  if [[ ${#resources[@]} -eq 0 ]]; then
    echo "Skipping $description: no matching resources found"
    return
  fi

  echo "Checking $description"
  for resource in "${resources[@]}"; do
    echo "  waiting for $resource"
    "${wait_cmd[@]}" --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True --timeout="$WAIT_TIMEOUT" "$resource" >/dev/null
  done
}

wait_for_ready_resources \
  "root:platform-mesh-system content configurations" \
  "${kcp_kubectl[@]}" --server "$KCP_URL/clusters/root:platform-mesh-system" get contentconfigurations.ui.platform-mesh.io

if workspace_exists "root:providers:httpbin-provider"; then
  wait_for_ready_resources_if_present \
    "httpbin provider content configurations" \
    "${kcp_kubectl[@]}" --server "$KCP_URL/clusters/root:providers:httpbin-provider" get contentconfigurations.ui.platform-mesh.io -A
else
  echo "Skipping httpbin provider content configurations: workspace root:providers:httpbin-provider not found"
fi

wait_for_ready_resources \
  "root:orgs stores" \
  "${kcp_kubectl[@]}" --server "$KCP_URL/clusters/root:orgs" get stores.core.platform-mesh.io

wait_for_ready_resources_if_present \
  "root:orgs identity provider configurations" \
  "${kcp_kubectl[@]}" --server "$KCP_URL/clusters/root:orgs" get identityproviderconfigurations.core.platform-mesh.io -A

wait_for_ready_resources \
  "root workspace types" \
  "${kcp_kubectl[@]}" --server "$KCP_URL/clusters/root" get workspacetypes.tenancy.kcp.io

wait_for_ready_resources_if_present \
  "root:orgs workspace types" \
  "${kcp_kubectl[@]}" --server "$KCP_URL/clusters/root:orgs" get workspacetypes.tenancy.kcp.io

echo "All backend resources are Ready"
