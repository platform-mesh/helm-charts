#!/bin/bash

KCP_CA_SECRET=root-frontproxy-server
KCP_ADMIN_SECRET=kcp-cluster-admin-client-cert
KCP_URL=https://localhost:8443
#KCP_URL=https://kcp.api.portal.cc-one.showroom.apeirora.eu

mkdir -p $PWD/.secret/kcp
kubectl --context kind-platform-mesh get secret kubeconfig-kcp-admin -n platform-mesh-system -o=jsonpath='{.data.kubeconfig}'|base64 -d > $PWD/.secret/kcp/admin.kubeconfig
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-context workspace.kcp.io/current --cluster=workspace.kcp.io/current --user=kcp-admin
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config use-context workspace.kcp.io/current