#!/bin/bash

# Prerelease setup functions for local development with locally built OCM components
# This script is sourced by start.sh when using the --prerelease flag

# Get kubectl exec flags; should not provide -t because users might have wrapper
# scripts for managed kubectl's or am trying to redirect the output of this script
# to a file.
# Must be called at point of use, not script init, because background jobs lose TTY
get_kubectl_exec_flags() {
    echo "-i"
}

wait_for_transfer_pod() {
  local timeout="${KUBECTL_WAIT_TIMEOUT:-1200s}"

  if kubectl wait --namespace default --for=condition=Ready pod \
    --timeout="$timeout" ocm-transfer-pod; then
    return 0
  fi

  echo -e "${RED}❌ Timed out after ${timeout} waiting for the OCM transfer pod. Pod and image-pull diagnostics:${COL_RES}" >&2
  kubectl get pod --namespace default ocm-transfer-pod -o wide >&2 || true
  kubectl describe pod --namespace default ocm-transfer-pod >&2 || true
  kubectl get events --namespace default \
    --field-selector involvedObject.kind=Pod,involvedObject.name=ocm-transfer-pod \
    --sort-by=.metadata.creationTimestamp >&2 || true
  return 1
}

# Deploy OCI registry for prerelease workflow
deploy_oci_registry() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Deploying local OCI registry ${COL_RES}"
  helm repo add twuni https://twuni.github.io/docker-registry.helm || true
  helm repo update
  kubectl create ns registry || true
  helm upgrade --install oci-registry twuni/docker-registry -n registry \
    --set service.port=443 \
    --set service.type=NodePort \
    --set service.nodePort=30500 \
    --set tlsSecretName=domain-certificate \
    --set image.repository=ghcr.io/distribution/distribution \
    --set image.tag=3.0.0 \
    --set ingress.enabled=false \
    --set configData.storage.delete.enabled=true

  kubectl create secret generic domain-certificate -n registry \
    --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
    --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
    --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
    --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

  kubectl wait --namespace registry \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT oci-registry-docker-registry

  echo -e "${COL}[$(date '+%H:%M:%S')] Local OCI registry is ready with TLS enabled.${COL_RES}"
  echo "To access it from the host:"
  echo "  kubectl --namespace registry port-forward service/oci-registry-docker-registry 8080:443"
  echo "  curl --insecure https://127.0.0.1:8080/v2/"
}

# Deploy transfer pod for OCM operations
deploy_transfer_pod() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Deploying OCM transfer pod ${COL_RES}"

  # Ensure the OCM CLI binary is present on the host before copying it into the pod
  source "$SCRIPT_DIR/ocm-setup.sh"
  setup_ocm_cli

  kubectl delete pod ocm-transfer-pod --ignore-not-found=true || true
  kubectl run ocm-transfer-pod --image=ghcr.io/platform-mesh/custom-images/ocmbuilder:sha-4a328ed -- sleep infinity
  wait_for_transfer_pod
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- mkdir -p .ocm

  # Configure CA on the pod
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- openssl s_client -connect oci-registry-docker-registry.registry.svc.cluster.local:443 -showcerts </dev/null 2>/dev/null| openssl x509 -outform PEM > $SCRIPT_DIR/registry-ca.pem
  kubectl cp $SCRIPT_DIR/registry-ca.pem -n default ocm-transfer-pod:registry-ca.pem
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- sudo cp registry-ca.pem /usr/local/share/ca-certificates/local-oci-registry_root_ca.crt
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- sudo update-ca-certificates
}

# Build and deploy prerelease OCM component
build_prerelease_component() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Building prerelease OCM component ${COL_RES}"
  "$SCRIPT_DIR/ocm-build-component.sh"
}

# Reconfigure CA trust on an already-running transfer pod (used during iterate)
reconfigure_transfer_pod_ca() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Reconfiguring CA on existing OCM transfer pod ${COL_RES}"
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- mkdir -p .ocm
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- openssl s_client -connect oci-registry-docker-registry.registry.svc.cluster.local:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM > $SCRIPT_DIR/registry-ca.pem
  kubectl cp $SCRIPT_DIR/registry-ca.pem -n default ocm-transfer-pod:registry-ca.pem
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- sudo cp registry-ca.pem /usr/local/share/ca-certificates/local-oci-registry_root_ca.crt
  kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- sudo update-ca-certificates
}

# Run the full prerelease setup workflow
run_prerelease_setup() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Using PRERELEASE OCM Component ${COL_RES}"

  # Deploy OCM infrastructure (skip on iterate — registry and transfer pod already exist)
  if [ "${ITERATE:-false}" = "true" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Skipping OCI registry and transfer pod deployment (--iterate) ${COL_RES}"
    reconfigure_transfer_pod_ca
  else
    deploy_oci_registry
    deploy_transfer_pod
  fi
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
  kubectl wait --namespace platform-mesh-system --for=condition=Ready component/platform-mesh --timeout=$KUBECTL_WAIT_TIMEOUT
}
