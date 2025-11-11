#!/bin/bash

DEBUG=${DEBUG:-false}

if [ "${DEBUG}" = "true" ]; then
  set -x
fi

set -e

COL='\033[92m'
RED='\033[91m'
YELLOW='\033[93m'
COL_RES='\033[0m'

KINDEST_VERSION="kindest/node:v1.33.1"

SCRIPT_DIR=$(dirname "$0")

# Parse command line arguments
PRERELEASE=false
MINIMAL=false
CACHED=false

for arg in "$@"; do
  case $arg in
    --prerelease)
      PRERELEASE=true
      ;;
    --minimal)
      MINIMAL=true
      ;;
    --cached)
      CACHED=true
      ;;
    *)
      # Unknown option, ignore or handle as needed
      ;;
  esac
done

# Source compatibility and environment checks
source "$SCRIPT_DIR/check-wsl-compatibility.sh"
source "$SCRIPT_DIR/check-environment.sh"

# Run WSL compatibility checks
check_wsl_compatibility

# Run environment checks
run_environment_checks

# Check if kind cluster is already running, if not create it
if ! check_kind_cluster; then
    if [ -d "$SCRIPT_DIR/certs" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Clearing existing certs directory ${COL_RES}"
        rm -rf "$SCRIPT_DIR/certs"
    fi
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
    $SCRIPT_DIR/../scripts/gen-certs.sh

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached image ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-cached.yaml --name platform-mesh --image=$KINDEST_VERSION
    else
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION
    fi
fi

mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "*.dev.local" "*.portal.dev.local" "oci-registry-docker-registry.registry.svc.cluster.local"
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

echo -e "${COL}[$(date '+%H:%M:%S')] Installing Traefik ${COL_RES}"
helm repo add traefik https://traefik.github.io/charts
helm upgrade --install --namespace=default \
  --set="experimental.kubernetesGateway.enabled=true" \
  --set="providers.kubernetesGateway.enabled=true" \
  --set="providers.kubernetesGateway.experimentalChannel=true" \
  --set="gatewayClass.enabled=true" \
  --set="service.type=NodePort" \
  --set="ports.websecure.nodePort=31000" \
  --set="ports.websecure.exposedPort=8443" \
  --set="gateway.enabled=false" \
  traefik traefik/traefik --version 37.3.0

echo -e "${COL}[$(date '+%H:%M:%S')] Installing flux ${COL_RES}"
helm upgrade -i -n flux-system --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
  --version 2.16.4 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set notificationController.create=false \
  --set helmController.container.additionalArgs[0]="--concurrent=10" \
  --set sourceController.container.additionalArgs[1]="--requeue-dependency=5s"

echo -e "${COL}[$(date '+%H:%M:%S')] Starting deployments ${COL_RES}"

echo -e "${COL}[$(date '+%H:%M:%S')] Install Cert-Manager ${COL_RES}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml
kubectl wait --namespace cert-manager \
  --for=condition=available deployment \
  --timeout=240s cert-manager-webhook
kubectl wait --namespace cert-manager \
  --for=condition=available deployment \
  --timeout=120s cert-manager
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=120s helm-controller
kubectl wait --namespace flux-system \
  --for=condition=available deployment \
  --timeout=120s source-controller

echo -e "${COL}[$(date '+%H:%M:%S')] OCM Controller and Platform Mesh ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/base

echo -e "${COL}[$(date '+%H:%M:%S')] Creating necessary secrets ${COL_RES}"
kubectl create secret tls iam-authorization-webhook-webhook-ca -n platform-mesh-system --key $SCRIPT_DIR/../webhook-config/ca.key --cert $SCRIPT_DIR/../webhook-config/ca.crt --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin-secret -n observability --from-literal=admin-user=admin --from-literal=admin-password=admin --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create secret generic slack-webhook-secret --from-literal=slack_webhook_url=https://hooks.slack.com/services/TEAMID/SERVICEID/TOKEN || echo "secret slack-webhook-secret already exists, skipping creation"

kubectl delete crds backendtlspolicies.gateway.networking.k8s.io --ignore-not-found=true
kubectl apply -k $SCRIPT_DIR/../kustomize/base/crds-extra

kubectl create secret generic domain-certificate -n default \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic domain-certificate -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic domain-certificate-ca -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/ca.crt --dry-run=client -oyaml | kubectl apply -f -

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=480s kyverno

echo -e "${COL}[$(date '+%H:%M:%S')] Kyverno policies ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/components/policies

# Hook: run optional mid-setup command(s) before applying Platform Mesh base
if [ -n "${START_MID_HOOK:-}" ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Running mid hook: ${START_MID_HOOK}${COL_RES}"
  eval "${START_MID_HOOK}"
fi

if [ "$PRERELEASE" = true ]; then
  # Prerelease mode flow
  echo -e "${COL}[$(date '+%H:%M:%S')] Apply k8s-ocm-toolkit-patch ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/k8s-ocm-toolkit-patch

  echo -e "${COL}[$(date '+%H:%M:%S')] Loading platform-mesh-operator docker image ${COL_RES}"
  kind load docker-image ghcr.io/platform-mesh/platform-mesh-operator:kcp-gates --name platform-mesh

  echo -e "${COL}[$(date '+%H:%M:%S')] Adding 'kind: PlatformMesh' resource ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-operator-prerelease

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=480s platform-mesh-operator

  echo -e "${COL}[$(date '+%H:%M:%S')] Adding 'prerelease' overlay ${COL_RES}"
  # Use prerelease default overlay to avoid installing platform-mesh repo/component
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/prerelease

  # Run prerelease OCM hook after the PlatformMesh resource exists so patches succeed
  if [ -n "${START_MID_HOOK2:-}" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running mid hook: ${START_MID_HOOK2}${COL_RES}"
    eval "${START_MID_HOOK2}"
  fi
else
  # Default mode flow
  echo -e "${COL}[$(date '+%H:%M:%S')] OCM Controller and PlatformMesh ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=480s platform-mesh-operator

  if [ -n "${START_MID_HOOK2:-}" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running mid hook: ${START_MID_HOOK2}${COL_RES}"
    eval "${START_MID_HOOK2}"
  fi

  echo -e "${COL}[$(date '+%H:%M:%S')] Adding 'kind: PlatformMesh' resource ${COL_RES}"
  if [ "$MINIMAL" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Installing minimal setup ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-minimal
  else
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource
  fi
fi

# wait for kind: PlatformMesh resource to become ready
echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for kind: PlatformMesh resource to become ready ${COL_RES}"
kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready platformmesh \
  --timeout=580s platform-mesh

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s keycloak
kubectl delete pod -l pkg.crossplane.io/provider=provider-keycloak -n crossplane-system

if [ "$MINIMAL" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Scaling down to minimal resources $COL_RES"
  kubectl scale deployment/ocm-k8s-toolkit-controller-manager --replicas=0 -n ocm-system
  kubectl scale deployment/kyverno-admission-controller --replicas=0 -n kyverno-system
  kubectl scale deployment/kyverno-background-controller --replicas=0 -n kyverno-system
  kubectl scale deployment/cert-manager --replicas=0 -n cert-manager
  kubectl scale deployment/cert-manager-cainjector --replicas=0 -n cert-manager
  kubectl scale deployment/cert-manager-webhook --replicas=0 -n cert-manager
  kubectl scale deployment/root-proxy --replicas=0 -n platform-mesh-system
  kubectl scale deployment/kcp-operator --replicas=0 -n kcp-operator
  kubectl scale deployment/etcd-druid --replicas=0 -n etcd-druid-system
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for helmreleases ${COL_RES}"
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s rebac-authz-webhook
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s account-operator
if [ "$MINIMAL" != true ]; then
  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=480s portal
fi
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s security-operator

if [ "$MINIMAL" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Scaling down to minimal resources $COL_RES"
  kubectl scale deployment/helm-controller --replicas=0 -n flux-system
  kubectl scale deployment/kustomize-controller --replicas=0 -n flux-system
  kubectl scale deployment/source-controller --replicas=0 -n flux-system
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing KCP Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

echo -e "${COL}Please create an entry in your /etc/hosts with the following line: \"127.0.0.1 default.portal.dev.local portal.dev.local kcp.api.portal.dev.local\" ${COL_RES}"
show_wsl_hosts_guidance

echo -e "${YELLOW}⚠️  WARNING: You need to add a hosts entry for every organization that is onboarded!${COL_RES}"
echo -e "${YELLOW}   Each organization will require its own subdomain entry in /etc/hosts${COL_RES}"
echo -e "${YELLOW}   Example: 127.0.0.1 <organization-name>.portal.dev.local${COL_RES}"

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.dev.local:8443 , any send emails can be received here: https://portal.dev.local:8443/mailpit ${COL_RES}"

if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
