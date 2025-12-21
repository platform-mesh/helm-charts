#!/bin/bash

KCP_CA_SECRET=root-frontproxy-server
KCP_ADMIN_SECRET=kcp-cluster-admin-client-cert
KCP_URL=https://kcp.api.portal.dev.local:8443
#KCP_URL=https://kcp.api.portal.cc-one.showroom.apeirora.eu

mkdir -p $PWD/.secret/kcp
kubectl --kubeconfig $PWD/.secret/platform-mesh.kubeconfig get secret $KCP_CA_SECRET -n platform-mesh-system -o=jsonpath='{.data.ca\.crt}' | base64 -d > $PWD/.secret/kcp/ca.crt
kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-cluster --embed-certs  workspace.kcp.io/current --server $KCP_URL/clusters/root --certificate-authority=$PWD/.secret/kcp/ca.crt
kubectl --kubeconfig $PWD/.secret/platform-mesh.kubeconfig get secret $KCP_ADMIN_SECRET -n platform-mesh-system -o=jsonpath='{.data.tls\.crt}' | base64 -d > $PWD/.secret/kcp/client.crt
kubectl --kubeconfig $PWD/.secret/platform-mesh.kubeconfig get secret $KCP_ADMIN_SECRET -n platform-mesh-system -o=jsonpath='{.data.tls\.key}' | base64 -d > $PWD/.secret/kcp/client.key
chmod 600 .secret/kcp/client.crt .secret/kcp/client.key
kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-credentials --embed-certs kcp-admin --client-certificate=.secret/kcp/client.crt --client-key=$PWD/.secret/kcp/client.key
kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config set-context workspace.kcp.io/current --cluster=workspace.kcp.io/current --user=kcp-admin
kubectl --kubeconfig=$PWD/.secret/kcp/admin.kubeconfig config use-context workspace.kcp.io/current