#!/bin/bash

DEFAULT_CONTEXT=kind-openmfp
DOMAIN=kcp.api.portal.dev.local

# Use the first argument as context if provided, otherwise use the default context
CONTEXT=${1:-$DEFAULT_CONTEXT}

CA=$(kubectl get secret -n openmfp-system kcp-cluster-admin-client-cert --context=${CONTEXT} -ojson | jq -r '.data."ca.crt"')
TLS_KEY=$(kubectl get secret -n openmfp-system kcp-cluster-admin-client-cert --context=${CONTEXT} -ojson | jq -r '.data."tls.key"')
TLS_CRT=$(kubectl get secret -n openmfp-system kcp-cluster-admin-client-cert --context=${CONTEXT} -ojson | jq -r '.data."tls.crt"')

KCP_ROOT_WS_URL=https://openmfp-kcp-front-proxy.openmfp-system:8443/clusters/root
KCP_OPENMFP_SYSTEM_WS_URL=https://openmfp-kcp-front-proxy.openmfp-system:8443/clusters/root:openmfp-system

function kubeconfig() {
  local clusterUrl=$1
  echo "apiVersion: v1
kind: Config
clusters:
- name: external-logical-cluster-admin
  cluster:
    certificate-authority-data: ${CA}
    server: \"${clusterUrl}\"
contexts:
- name: external-logical-cluster
  context:
    cluster: external-logical-cluster-admin
    user: external-logical-cluster-admin
current-context: external-logical-cluster
users:
- name: external-logical-cluster-admin
  user:
    client-certificate-data: ${TLS_CRT}
    client-key-data: ${TLS_KEY}"
}

ROOT_KUBECONFIG=$(kubeconfig ${KCP_ROOT_WS_URL})
OPENMFP_SYSTEM_KUBECONFIG=$(kubeconfig ${KCP_OPENMFP_SYSTEM_WS_URL})

kubectl apply --context=${CONTEXT} -f - <<EOF
apiVersion: v1
data:
  rootKubeconfig: $(echo "${ROOT_KUBECONFIG}" | base64 -w 0)
  openmfpSystemKubeconfig: $(echo "${OPENMFP_SYSTEM_KUBECONFIG}" | base64 -w 0)
  kubeconfig: $(echo "${OPENMFP_SYSTEM_KUBECONFIG}" | base64 -w 0)
kind: Secret
metadata:
  namespace: default
  name: kcp-kubeconfig
type: Opaque
EOF

kubectl apply --context=${CONTEXT} -f - <<EOF
apiVersion: v1
data:
  rootKubeconfig: $(echo "${ROOT_KUBECONFIG}" | base64 -w 0)
  openmfpSystemKubeconfig: $(echo "${OPENMFP_SYSTEM_KUBECONFIG}" | base64 -w 0)
  kubeconfig: $(echo "${OPENMFP_SYSTEM_KUBECONFIG}" | base64 -w 0)
kind: Secret
metadata:
  namespace: openmfp-system
  name: kcp-kubeconfig
type: Opaque
EOF
