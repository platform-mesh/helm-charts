#!/bin/bash

KCP_ADMIN_SECRET=kubeconfig-kcp-admin

mkdir -p $PWD/.secret/kcp
kubectl --context kind-platform-mesh get secret kubeconfig-kcp-admin -n platform-mesh-system -o=jsonpath='{.data.kubeconfig}'|base64 -d > $PWD/.secret/kcp/admin.kubeconfig
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-context workspace.kcp.io/current --cluster=workspace.kcp.io/current --user=kcp-admin
# kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config use-context workspace.kcp.io/current
