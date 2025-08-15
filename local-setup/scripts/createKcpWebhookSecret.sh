#!/bin/bash

# TODO: Creates kcp-webhook-secret with kubeconfig for the webhook

DEFAULT_CONTEXT=kind-openmfp
CONTEXT=${1:-$DEFAULT_CONTEXT}

WEBHOOK_URL=https://rebac-authz-webhook.platform-mesh-system.svc.cluster.local:9443/authz

until kubectl get secret rebac-authz-webhook-cert -n platform-mesh-system --context=${CONTEXT} >/dev/null 2>&1; do
    echo "Waiting for secret rebac-authz-webhook-cert to be created..."
    sleep 10
done

CA_VALUE_BASE64=$(kubectl get secret openmfp-rebac-authz-webhook-cert -n openmfp-system --context=${CONTEXT} -o jsonpath="{.data['ca\.crt']}" | tr -d '\n')

function kubeconfig() {
  local clusterUrl=$1
  echo "apiVersion: v1
kind: Config
clusters:
- name: webhook
  cluster:
    certificate-authority-data: \"${CA_VALUE_BASE64}\"
    server: \"${clusterUrl}\"
current-context: webhook
contexts:
- name: webhook
  context:
    cluster: webhook"
}

KUBECONFIG_BASE64=$(kubeconfig ${WEBHOOK_URL} | base64 -w 0)

# Create the kcp-webhook-secret
kubectl apply --context=${CONTEXT} -f - <<EOF
apiVersion: v1
data:
  kubeconfig: ${KUBECONFIG_BASE64}
kind: Secret
metadata:
  namespace: openmfp-system
  name: kcp-webhook-secret
type: Opaque
EOF
