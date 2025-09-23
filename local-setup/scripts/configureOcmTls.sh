#!/bin/bash

# # get registry CA
# openssl s_client -connect oci-registry-docker-registry.registry.svc.cluster.local:9443 -showcerts </dev/null 2>/dev/null| openssl x509 -outform PEM > registry-ca.pem

# patch ocm-controller-manager to trust the local OCI registry CA
kubectl -n ocm-system create configmap ocm-custom-ca   --from-file=registry-ca.pem=registry-ca.pem || true
# kubectl -n flux-system create configmap ocm-custom-ca --from-file=registry-ca.pem=registry-ca.pem || true
kubectl create secret generic domain-certificate-ca -n flux-system --from-file=registry-ca.pem=local-setup/scripts/certs/ca.crt --dry-run=client -oyaml | kubectl apply -f -

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
