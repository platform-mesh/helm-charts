#!/bin/bash

# Copy the RootCA from openmfp-rebac-authz-webhook-cert and update with it the kubeconfig in kcp-webhook-secret

until kubectl get secret openmfp-rebac-authz-webhook-cert -n openmfp-system >/dev/null 2>&1; do
    echo "Waiting for secret openmfp-rebac-authz-webhook-cert to be created..."
    sleep 10
done

until kubectl get secret kcp-webhook-secret -n openmfp-system >/dev/null 2>&1; do
    echo "Waiting for secret kcp-webhook-secret to be created..."
    sleep 10
done

patch_value=$(kubectl get secret openmfp-rebac-authz-webhook-cert -n openmfp-system -o yaml|yq '.data["ca.crt"]')
# echo "$patch_value"

KCP_KUBECONFIG=$(kubectl get secret kcp-webhook-secret -n openmfp-system -o yaml|yq '.data["kubeconfig"]'|base64 -d)
# echo "$KCP_KUBECONFIG"

export patch_value
updated_kubeconfig=$(echo "$KCP_KUBECONFIG" | \
  yq eval '.clusters[0].cluster."certificate-authority-data" = strenv(patch_value)' -)
# echo "$updated_kubeconfig"

base64_new_kubeconfig=$(echo "$updated_kubeconfig" | base64 -w 0)
# echo "$base64_new_kubeconfig"

# Then, patch the secret using the encoded value
kubectl patch secret kcp-webhook-secret -n openmfp-system --type='json' \
  -p='[{"op": "replace", "path": "/data/kubeconfig", "value": "'"$base64_new_kubeconfig"'"}]'
