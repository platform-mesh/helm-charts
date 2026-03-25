#!/bin/bash

KCP_ADMIN_SECRET=kubeconfig-kcp-admin

mkdir -p $PWD/.secret/kcp
kubectl --context kind-platform-mesh get secret $KCP_ADMIN_SECRET -n platform-mesh-system -o=jsonpath='{.data.kubeconfig}' | base64 -d > $PWD/.secret/kcp/admin.kubeconfig