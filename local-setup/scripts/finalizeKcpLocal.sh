#!/usr/bin/env bash
#
# Post-install steps that every local KCP setup needs but the Flux/Helm
# chart path can't produce on its own.
#
# 1. Patch CoreDNS so in-cluster pods resolve `root.kcp.localhost` and the
#    other localhost-based KCP URLs to the Traefik ClusterIP (the only
#    in-cluster service listening on 8443). Without this, sync-agents and
#    the portal fail to reach KCP from inside the cluster.
#
# 2. Disable the security workspace initializer. The security operator
#    cannot manage Keycloak realms locally (403 Forbidden), which blocks
#    WorkspaceType initialization and leaves new workspaces stuck in
#    "Initializing".
#
# 3. Ensure the `root:providers` KCP workspace exists so per-provider
#    tutorials (private-llm, chat-ui, etc.) can go straight to
#    `kubectl kcp workspace create <provider> --type=root:provider`
#    without the prerequisite of creating the parent workspace first.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
KCP_KUBECONFIG="$SCRIPT_DIR/../../.secret/kcp/admin.kubeconfig"
KCP_URL="${KCP_URL:-https://localhost:8443}"

COL=${COL:-"\033[0;36m"}
COL_RES=${COL_RES:-"\033[0m"}

echo -e "${COL}[$(date '+%H:%M:%S')] Patching CoreDNS to resolve kcp.localhost hostnames to Traefik ${COL_RES}"
TRAEFIK_IP=$(kubectl get svc -n default traefik -o jsonpath='{.spec.clusterIP}')
kubectl get configmap coredns -n kube-system -o json | \
  python3 -c "
import sys, json
cm = json.load(sys.stdin)
ip = '$TRAEFIK_IP'
hosts_block = f'''hosts {{
           {ip} localhost portal.localhost kcp.localhost root.kcp.localhost
           fallthrough
        }}
        '''
corefile = cm['data']['Corefile']
# Idempotent: only inject the hosts block if it isn't already present.
if 'root.kcp.localhost' not in corefile:
    cm['data']['Corefile'] = corefile.replace(
        'kubernetes cluster.local', hosts_block + 'kubernetes cluster.local')
json.dump(cm, sys.stdout)
" | kubectl apply -f - >/dev/null

kubectl rollout restart deploy coredns -n kube-system >/dev/null
kubectl rollout status deploy coredns -n kube-system --timeout=60s >/dev/null

echo -e "${COL}[$(date '+%H:%M:%S')] Disabling security workspace initializer (Keycloak realm creation is not supported locally) ${COL_RES}"
kubectl scale deploy -n platform-mesh-system security-operator-initializer --replicas=0 >/dev/null
kubectl --kubeconfig="$KCP_KUBECONFIG" patch workspacetype security \
  --server="$KCP_URL/clusters/root" \
  --type=merge -p '{"spec":{"initializer":false}}' >/dev/null

echo -e "${COL}[$(date '+%H:%M:%S')] Ensuring root:providers workspace exists ${COL_RES}"
KUBECONFIG="$KCP_KUBECONFIG" kubectl create-workspace providers \
  --type=root:providers --ignore-existing \
  --server="$KCP_URL/clusters/root" >/dev/null
