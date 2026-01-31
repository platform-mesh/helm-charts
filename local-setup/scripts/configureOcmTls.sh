#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Verify the certificate file exists
if [ ! -f "$SCRIPT_DIR/registry-ca.pem" ]; then
  echo "Error: $SCRIPT_DIR/registry-ca.pem not found"
  exit 1
fi

# Create ocm-system namespace if it doesn't exist
kubectl create namespace ocm-system --dry-run=client -oyaml | kubectl apply -f -

# patch ocm-controller-manager to trust the local OCI registry CA
echo "Creating configmap ocm-custom-ca in ocm-system namespace..."
kubectl -n ocm-system create configmap ocm-custom-ca --from-file=registry-ca.pem=$SCRIPT_DIR/registry-ca.pem --dry-run=client -oyaml | kubectl apply -f -

# Also create for flux
kubectl create secret generic domain-certificate-ca -n flux-system --from-file=registry-ca.pem=$SCRIPT_DIR/certs/ca.crt --dry-run=client -oyaml | kubectl apply -f -

# patch flux source-controller to trust the local OCI registry CA
kubectl -n flux-system patch deployment source-controller --type strategic --patch '
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        - name: SSL_CERT_FILE
          value: /etc/flux/ca/registry-ca.pem
        volumeMounts:
        - name: custom-ca
          mountPath: /etc/flux/ca
          readOnly: true
      volumes:
      - name: custom-ca
        secret:
          secretName: domain-certificate-ca
'
