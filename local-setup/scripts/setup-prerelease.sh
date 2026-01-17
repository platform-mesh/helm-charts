#!/bin/bash

# Prerelease setup functions for local development with locally built OCM components
# This script is sourced by start.sh when using the --prerelease flag

# Deploy OCI registry for prerelease workflow
deploy_oci_registry() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Deploying local OCI registry ${COL_RES}"
  helm repo add twuni https://twuni.github.io/docker-registry.helm || true
  helm repo update
  kubectl create ns registry || true
  helm upgrade --install oci-registry twuni/docker-registry -n registry \
    --set service.port=443 \
    --set tlsSecretName=domain-certificate \
    --set image.repository=ghcr.io/distribution/distribution \
    --set image.tag=3.0.0 \
    --set ingress.enabled=false

  kubectl create secret generic domain-certificate -n registry \
    --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
    --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
    --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
    --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

  kubectl wait --namespace registry \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT oci-registry-docker-registry
}

# Deploy transfer pod for OCM operations
deploy_transfer_pod() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Deploying OCM transfer pod ${COL_RES}"
  kubectl delete pod ocm-transfer-pod --ignore-not-found=true || true
  kubectl run ocm-transfer-pod --image=ghcr.io/platform-mesh/images/ocmbuilder:pr-4 -- sleep infinity
  kubectl wait --namespace default --for=condition=Ready pod --timeout=480s ocm-transfer-pod
  kubectl exec -ti ocm-transfer-pod -- mkdir -p .ocm

  # Configure CA on the pod
  kubectl exec -ti ocm-transfer-pod -- openssl s_client -connect oci-registry-docker-registry.registry.svc.cluster.local:443 -showcerts </dev/null 2>/dev/null| openssl x509 -outform PEM > $SCRIPT_DIR/registry-ca.pem
  kubectl cp $SCRIPT_DIR/registry-ca.pem -n default ocm-transfer-pod:registry-ca.pem
  kubectl exec -ti ocm-transfer-pod -- sudo cp registry-ca.pem /usr/local/share/ca-certificates/local-oci-registry_root_ca.crt
  kubectl exec -ti ocm-transfer-pod -- sudo update-ca-certificates
}

# Build and deploy prerelease OCM component
build_prerelease_component() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Building prerelease OCM component ${COL_RES}"
  pushd "$SCRIPT_DIR/../.." > /dev/null
  task ocm:build
  popd > /dev/null
}

# Run the full prerelease setup workflow
run_prerelease_setup() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Using PRERELEASE OCM Component ${COL_RES}"

  # Deploy OCM infrastructure
  deploy_oci_registry
  deploy_transfer_pod
  $SCRIPT_DIR/configureOcmTls.sh

  # Build prerelease component
  build_prerelease_component

  # Apply prerelease overlay
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/ocm-prerelease

  # Wait for OCM controller to be updated with TLS config and restart if needed
  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for OCM controller to be ready with TLS config ${COL_RES}"
  sleep 5
  kubectl rollout restart deployment/ocm-k8s-toolkit-controller-manager -n ocm-system 2>/dev/null || true
  kubectl wait --namespace ocm-system --for=condition=available deployment/ocm-k8s-toolkit-controller-manager --timeout=$KUBECTL_WAIT_TIMEOUT 2>/dev/null || true

  # Wait for OCM platform-mesh component to be ready (this deploys the platform-mesh-operator)
  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for OCM platform-mesh component to reconcile ${COL_RES}"
  kubectl wait --namespace default --for=condition=Ready component/platform-mesh --timeout=$KUBECTL_WAIT_TIMEOUT
}
