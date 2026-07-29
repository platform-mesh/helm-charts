#!/usr/bin/env bash

# Small script to dump kcp+runtime cluster state when something fails in CI.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DOMAIN="${BASE_DOMAIN:-portal.localhost}"
KCP_URL="${KCP_URL:-https://kcp.api.${BASE_DOMAIN}:8443}"
KCP_KUBECONFIG="${KCP_KUBECONFIG:-$ROOT_DIR/.secret/kcp/admin.kubeconfig}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/runtime-artifacts}"

runtime_kubectl() {
    if [[ -n "${RUNTIME_KUBECONFIG:-}" ]]; then
        kubectl --kubeconfig "$RUNTIME_KUBECONFIG" "$@"
    else
        kubectl "$@"
    fi
}

dump_runtime() {
    local out="$1"
    mkdir -p "$out"

    runtime_kubectl get -A -o yaml \
        platformmesh,component,resource,helmrelease,helmchart,helmrepository,ocirepository,kustomization,deployment \
        > "$out/resources.yaml"
    runtime_kubectl get pods -A -o wide > "$out/pods.yaml"
    runtime_kubectl get events -A -o yaml --sort-by=.lastTimestamp > "$out/events.yaml"

    mkdir -p "$1/logs"
    runtime_kubectl get pods -A -o custom-columns=NS:.metadata.namespace,N:.metadata.name --no-headers | while read -r ns pod; do
        [[ -z "$ns" || -z "$pod" ]] && continue
        mkdir -p "$OUT_DIR/logs/$ns"
        runtime_kubectl logs -n "$ns" "$pod" --all-containers --tail=-1 > "$1/logs/$ns/$pod.log" 2>&1
        runtime_kubectl logs -n "$ns" "$pod" --all-containers --previous --tail=-1 > "$1/logs/$ns/$pod.previous.log" 2>/dev/null || true
    done
}

kcp_kubectl() {
    kubectl --kubeconfig "$KCP_KUBECONFIG" --server "$KCP_URL/clusters/$1" "${@:2}"
}

dump_kcp() {
    if [[ ! -f "$KCP_KUBECONFIG" ]]; then
        echo "kcp admin kubeconfig not found at $KCP_KUBECONFIG, skipping kcp dump" >&2
        return
    fi
    local out="$1"

    kcp_kubectl root get workspaces.tenancy.kcp.io -o yaml > "$out/workspaces-root.yaml"
    kcp_kubectl root:orgs get workspaces.tenancy.kcp.io -o yaml > "$out/workspaces-root_orgs.yaml"
    kcp_kubectl root:orgs get workspacetypes.tenancy.kcp.io -o yaml > "$out/workspacetypes.yaml"

    kcp_kubectl root:orgs get workspaces.tenancy.kcp.io -o custom-columns=N:.metadata.name --no-headers | while read -r orgs; do
        [[ -z "$org" ]] && continue
        kcp_kubectl "root:orgs:$org" get workspaces.tenancy.kcp.io -o yaml > "$out/workspaces-org-$org.yaml"
        kcp_kubectl "root:orgs:$org" get accounts.core.platform-mesh.io -A -o yaml > "$out/accounts-$org.yaml"
    done
}

dump_runtime "$OUT_DIR/runtime"
dump_kcp "$OUT_DIR/kcp"
