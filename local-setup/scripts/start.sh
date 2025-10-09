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
        echo -e "${COL}[$(date '+%H:%M:%S')] Clearning existing certs directory ${COL_RES}"
        rm -rf $SCRIPT_DIR/certs
    fi
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
    $SCRIPT_DIR/../scripts/gen-certs.sh

    if [ "$1" == "--cached" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached image ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-cached.yaml --name platform-mesh --image=$KINDEST_VERSION
    else
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION
    fi
fi

mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "*.dev.local" "*.portal.dev.local" "oci-registry-docker-registry.registry.svc.cluster.local"
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt


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

kubectl create secret generic domain-certificate -n istio-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -
kubectl create secret generic domain-certificate -n default \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic domain-certificate-ca -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/ca.crt --dry-run=client -oyaml | kubectl apply -f -

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=480s kyverno

echo -e "${COL}[$(date '+%H:%M:%S')] OCM Controller and Platform Mesh ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/components/policies

echo -e "${COL}[$(date '+%H:%M:%S')] OCM Controller and PlatformMesh ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/default
#
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=480s platform-mesh-operator


echo -e "${COL}[$(date '+%H:%M:%S')] Adding 'kind: PlatformMesh' resource ${COL_RES}"
kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource

# wait for kind: PlatformMesh resource to become ready
echo -e "$COL Waiting for kind: PlatformMesh resource to become ready $COL_RES"
kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready platformmesh \
  --timeout=580s platform-mesh

kubectl apply -k $SCRIPT_DIR/../kustomize/components/kcp-hotfix

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s keycloak
kubectl delete pod -l pkg.crossplane.io/provider=provider-keycloak -n crossplane-system
kubectl rollout restart deployment portal -n platform-mesh-system

kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s rebac-authz-webhook
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s account-operator
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=480s portal
kubectl wait --namespace default \
  --for=condition=Ready helmreleases \
  --timeout=280s security-operator

# Restart deployments to ensure they pick up updates
kubectl rollout restart deployment root-kcp -n platform-mesh-system
kubectl rollout restart deployment frontproxy-front-proxy -n platform-mesh-system
kubectl rollout status deployment root-kcp -n platform-mesh-system
kubectl rollout status deployment frontproxy-front-proxy -n platform-mesh-system

kubectl rollout restart deployment rebac-authz-webhook -n platform-mesh-system
kubectl rollout status deployment rebac-authz-webhook -n platform-mesh-system

kubectl rollout status deployment virtual-workspaces -n platform-mesh-system
kubectl rollout restart deployment virtual-workspaces -n platform-mesh-system

kubectl rollout restart deployment kubernetes-graphql-gateway -n platform-mesh-system
kubectl rollout status deployment kubernetes-graphql-gateway -n platform-mesh-system

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing KCP Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for default organization to be ready ${COL_RES}"

kubectl wait \
  --server='https://kcp.api.portal.dev.local:8443/clusters/root:orgs' \
  --kubeconfig=$SCRIPT_DIR/../../.secret/kcp/admin.kubeconfig \
  --for=condition=Ready accounts \
  --timeout=280s default

echo -e "${COL}Please create an entry in your /etc/hosts with the following line: \"127.0.0.1 default.portal.dev.local portal.dev.local kcp.api.portal.dev.local\" ${COL_RES}"
show_wsl_hosts_guidance

echo -e "${YELLOW}⚠️  WARNING: You need to add a hosts entry for every organization that is onboarded!${COL_RES}"
echo -e "${YELLOW}   Each organization will require its own subdomain entry in /etc/hosts${COL_RES}"
echo -e "${YELLOW}   Example: 127.0.0.1 <organization-name>.portal.dev.local${COL_RES}"

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.dev.local:8443 or the default organization at: https://default.portal.dev.local:8443 ${COL_RES}"


if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
