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

# kcp-operator embeds only the intermediate CA (root-server-ca) in
# certificate-authority-data. Node's TLS stack rejects this with
# UNABLE_TO_GET_ISSUER_CERT because the chain doesn't terminate at a
# self-signed anchor. Append the kcp root CA so Node-based clients (e.g.
# the portal backend via @kubernetes/client-node) can validate.
ROOT_CA_PEM=$(kubectl --context kind-platform-mesh -n platform-mesh-system get secret root-ca -o=jsonpath='{.data.ca\.crt}' | base64 -d)
INT_CA_PEM=$(yq -r '.clusters[0].cluster["certificate-authority-data"]' $PWD/.secret/kcp/admin.kubeconfig | base64 -d)
COMBINED_CA=$(printf '%s\n%s\n' "$INT_CA_PEM" "$ROOT_CA_PEM" | base64 -w0)
yq -i "(.clusters[].cluster.\"certificate-authority-data\") = \"$COMBINED_CA\"" $PWD/.secret/kcp/admin.kubeconfig
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-context workspace.kcp.io/current --cluster=workspace.kcp.io/current --user=kcp-admin
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config use-context workspace.kcp.io/current