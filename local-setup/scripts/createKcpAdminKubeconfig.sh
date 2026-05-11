#!/bin/bash

KCP_CA_SECRET=root-frontproxy-server
KCP_ADMIN_SECRET=kcp-cluster-admin-client-cert
KCP_URL=https://localhost:8443
#KCP_URL=https://kcp.api.portal.cc-one.showroom.apeirora.eu

SHARDED=${1:-false}

mkdir -p $PWD/.secret/kcp
kubectl --context kind-platform-mesh get secret kubeconfig-kcp-admin -n platform-mesh-system -o=jsonpath='{.data.kubeconfig}'|base64 -d > $PWD/.secret/kcp/admin.kubeconfig

# TODO remove when kcp-operator uses front-proxy address for kcp-admin kubeconfig instead of root shard
# Override server URLs to use localhost (front-proxy host) instead of root.kcp.localhost only in sharded mode
if [ "$SHARDED" = true ]; then
    sed -i 's|https://root\.kcp\.localhost:8443/|https://localhost:8443/|g' $PWD/.secret/kcp/admin.kubeconfig
fi

# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-context workspace.kcp.io/current --cluster=workspace.kcp.io/current --user=kcp-admin
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config use-context workspace.kcp.io/current