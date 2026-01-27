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

KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-900s}"
KINDEST_VERSION="kindest/node:v1.34.0"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
LATEST=false
DEPLOYMENT_TECH="fluxcd"

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--latest] [--deployment-tech=fluxcd|argocd] [--help]"
  echo "  --deployment-tech: Choose deployment technology (fluxcd or argocd). Default: fluxcd"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --latest) LATEST=true ;;
    --deployment-tech=*)
      DEPLOYMENT_TECH="${1#*=}"
      if [ "$DEPLOYMENT_TECH" != "fluxcd" ] && [ "$DEPLOYMENT_TECH" != "argocd" ]; then
        echo "Error: --deployment-tech must be either 'fluxcd' or 'argocd'" >&2
        usage
      fi
      ;;
    --help|-h) usage ;;
    --*) echo "Unknown option: $1" >&2; usage ;;
    *) echo "Ignoring positional arg: $1" ;;
  esac
  shift
done

# Source compatibility and environment checks
source "$SCRIPT_DIR/check-wsl-compatibility.sh"
source "$SCRIPT_DIR/check-environment.sh"
source "$SCRIPT_DIR/setup-registry-proxies.sh"

# Run WSL compatibility checks
check_wsl_compatibility

# Run environment checks
run_environment_checks

# Start registry proxies if using cached mode
if [ "$CACHED" = true ]; then
    setup_registry_proxies
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Using deployment technology: ${DEPLOYMENT_TECH} ${COL_RES}"

# Check if kind cluster is already running, if not create it
if ! check_kind_cluster; then
    if [ -d "$SCRIPT_DIR/certs" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Clearing existing certs directory ${COL_RES}"
        rm -rf "$SCRIPT_DIR/certs"
    fi
    $SCRIPT_DIR/../scripts/gen-certs.sh

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached images ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-cached.yaml --name platform-mesh --image=$KINDEST_VERSION --quiet
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION --quiet
    fi
    kind export kubeconfig --name platform-mesh --kubeconfig=.secret/platform-mesh.kubeconfig
fi

# Check if kind infra cluster is already running, if not create it
if ! check_kind_infra_cluster; then
    if [ -d "$SCRIPT_DIR/certs" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Clearing existing certs directory ${COL_RES}"
        rm -rf "$SCRIPT_DIR/certs"
    fi
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind infra cluster ${COL_RES}"
    $SCRIPT_DIR/../scripts/gen-certs.sh

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind infra cluster with cached image ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-infra-cached.yaml --name platform-mesh-infra --image=$KINDEST_VERSION
    else
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-infra.yaml --name platform-mesh-infra --image=$KINDEST_VERSION
    fi
    kind export kubeconfig --name platform-mesh-infra --kubeconfig=.secret/platform-mesh-infra.kubeconfig

fi

kind load docker-image ghcr.io/platform-mesh/platform-mesh-operator:v0.27.0-rc.11 --name platform-mesh-infra

mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "portal.localhost" "*.portal.localhost" "oci-registry-docker-registry.registry.svc.cluster.local" 2>/dev/null
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

install_fluxcd() {
  local kubeconfig=$1
  local concurrent=$2
  local namespace="flux-system"
  
  echo -e "${COL}[$(date '+%H:%M:%S')] Installing FluxCD ${COL_RES}"
  HELM_REGISTRY_CONFIG=/tmp/helm-no-auth.json helm upgrade --kubeconfig "$kubeconfig" -i -n "$namespace" --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
    --version 2.17.1 \
    --set imageAutomationController.create=false \
    --set imageReflectionController.create=false \
    --set notificationController.create=false \
    --set helmController.container.additionalArgs[0]="--concurrent=$concurrent" \
    --set sourceController.container.additionalArgs[1]="--requeue-dependency=5s" > /dev/null 2>&1

  kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT helm-controller > /dev/null 2>&1
  kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT source-controller > /dev/null 2>&1
  kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT kustomize-controller > /dev/null 2>&1
}

install_argocd() {
  local kubeconfig=$1
  local namespace="argocd"
  
  echo -e "${COL}[$(date '+%H:%M:%S')] Installing ArgoCD ${COL_RES}"
  HELM_REGISTRY_CONFIG=/tmp/helm-no-auth.json helm upgrade --kubeconfig "$kubeconfig" -i -n "$namespace" --create-namespace argo-cd oci://ghcr.io/argoproj/argo-helm/argo-cd \
    --version 9.2.4 \
    --set controller.replicas=1 \
    --set server.replicas=1 \
    --set repoServer.replicas=1 \
    --set applicationSet.replicas=1 \
    --set notifications.enabled=false \
    --set dex.enabled=false \
    --set configs.params."server\.insecure"=true > /dev/null 2>&1

  echo "Waiting for ArgoCD server to be ready"

  kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT argo-cd-argocd-applicationset-controller > /dev/null 2>&1
  kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT argo-cd-argocd-repo-server > /dev/null 2>&1
  kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT argo-cd-argocd-server > /dev/null 2>&1
}

setup_argocd() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Setting up ArgoCD clusters ${COL_RES}"
  kind export kubeconfig --name platform-mesh-infra
  argocd login --core
  kubectl config set-context --current --namespace=argocd
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data": {"application.namespaces": "argocd,platform-mesh-system"}}'

  CA_DATA=$(yq '.clusters[0].cluster["certificate-authority-data"]' .secret/platform-mesh.kubeconfig.tmp)
  CERT_DATA=$(yq '.users[0].user["client-certificate-data"]' .secret/platform-mesh.kubeconfig.tmp)
  CERT_KEY=$(yq '.users[0].user["client-key-data"]' .secret/platform-mesh.kubeconfig.tmp)

export CERTCONFIG="$(cat <<EOF
{
  "tlsClientConfig": {
    "insecure": false,
    "caData": "$CA_DATA",
    "certData": "$CERT_DATA",
    "keyData": "$CERT_KEY"
  }
}
EOF
)"
  yq -i '
    .stringData.config = (strenv(CERTCONFIG) + "\n")
    | .stringData.config style="literal"
  ' local-setup/kustomize/overlays/infra/platform-mesh-cluster-secret.yml
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f local-setup/kustomize/overlays/infra/platform-mesh-cluster-secret.yml
  kubectl delete pod -n argocd -l app.kubernetes.io/instance=argo-cd
}

wait_for_deployment_resource() {
  local kubeconfig=$1
  local namespace=$2
  local resource_name=$3
  
  if [ "$DEPLOYMENT_TECH" = "fluxcd" ]; then
    kubectl --kubeconfig "$kubeconfig" wait --namespace "$namespace" \
      --for=condition=Ready helmreleases \
      --timeout=$KUBECTL_WAIT_TIMEOUT "$resource_name"
  elif [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    # ArgoCD Applications use health and sync status instead of Ready condition
    # Wait for both health=Healthy and sync=Synced
    local elapsed=0
    local timeout_seconds=$(echo "$KUBECTL_WAIT_TIMEOUT" | sed 's/s$//')
    while [ $elapsed -lt $timeout_seconds ]; do
      local health=$(kubectl --kubeconfig "$kubeconfig" get application "$resource_name" -n "$namespace" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
      local sync=$(kubectl --kubeconfig "$kubeconfig" get application "$resource_name" -n "$namespace" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
      if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
        return 0
      fi
      sleep 2
      elapsed=$((elapsed + 2))
    done
    echo "Warning: Application $resource_name did not become Healthy and Synced within timeout" >&2
    return 1
  fi
}

install_fluxcd .secret/platform-mesh-infra.kubeconfig 50
install_fluxcd .secret/platform-mesh.kubeconfig 10

if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
  install_argocd .secret/platform-mesh-infra.kubeconfig
  install_argocd .secret/platform-mesh.kubeconfig
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Install KRO and OCM ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/kro
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit
kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit


echo -e "${COL}[$(date '+%H:%M:%S')] Install CRDs ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/crds
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/crds

echo -e "${COL}[$(date '+%H:%M:%S')] Creating namespaces ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces

# add platform-mesh kubeconfig to the infra cluster as a secret
cp .secret/platform-mesh.kubeconfig .secret/platform-mesh.kubeconfig.tmp
IP_ADDR=$(docker inspect platform-mesh-control-plane|jq '.[0] | .NetworkSettings | .Networks | .kind | .IPAddress' -r)
kubectl config set-cluster kind-platform-mesh \
  --server=https://$IP_ADDR:6443 \
  --kubeconfig=.secret/platform-mesh.kubeconfig.tmp
kubectl create secret generic platform-mesh-kubeconfig -n platform-mesh-system \
  --from-file=kubeconfig=.secret/platform-mesh.kubeconfig.tmp --dry-run=client -o yaml | kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f -
kubectl create secret generic platform-mesh-kubeconfig -n default \
  --from-file=kubeconfig=.secret/platform-mesh.kubeconfig.tmp --dry-run=client -o yaml | kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f -

# wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig default kro

echo -e "${COL}[$(date '+%H:%M:%S')] Creating necessary secrets ${COL_RES}"
kubectl create secret tls iam-authorization-webhook-webhook-ca -n platform-mesh-system --key $SCRIPT_DIR/../webhook-config/ca.key --cert $SCRIPT_DIR/../webhook-config/ca.crt --dry-run=client -o yaml | kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f -
kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f -

kubectl create secret generic domain-certificate -n default \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f -

kubectl create secret generic domain-certificate -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
  --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
  --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
  --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f -

kubectl create secret generic domain-certificate-ca -n platform-mesh-system \
  --from-file=tls.crt=$SCRIPT_DIR/certs/ca.crt --dry-run=client -oyaml | kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f -

echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh CRDs ${COL_RES}"
kubectl  --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/platform-mesh-operator-crds
sleep 5
kubectl  --kubeconfig .secret/platform-mesh.kubeconfig wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=120s


echo -e "${COL}[$(date '+%H:%M:%S')] Install port-fixer on platform-mesh cluster ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/port-fixer

kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces
kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-new

echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/rgd
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace default \
  --for=condition=Ready resourcegraphdefinition \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator


setup_argocd

kubectl  --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/infra
kubectl  --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/runtime

kubectl  --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace default \
  --for=condition=Ready PlatformMeshOperator \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator

patch_platform_mesh_operator_roles() {
  echo -e "${COL}[$(date '+%H:%M:%S')] Patching Platform-Mesh Operator roles to include ArgoCD permissions ${COL_RES}"
  # Temporary: patch the ClusterRole until the chart is updated
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig patch clusterrole platform-mesh-operator --type='json' -p='[
    {"op": "add", "path": "/rules/-", "value": {"apiGroups": ["argoproj.io"], "resources": ["appprojects"], "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]}},
    {"op": "add", "path": "/rules/-", "value": {"apiGroups": ["argoproj.io"], "resources": ["applications"], "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]}}
  ]'
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig patch role platform-mesh-operator -n platform-mesh-system --type='json' -p='[
    {"op": "add", "path": "/rules/-", "value": {"apiGroups": ["argoproj.io"], "resources": ["appprojects"], "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]}},
    {"op": "add", "path": "/rules/-", "value": {"apiGroups": ["argoproj.io"], "resources": ["applications"], "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]}}
  ]'

  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig delete pod -l app=platform-mesh-operator -n platform-mesh-system
}

patch_platform_mesh_operator_roles

# Install Platform-Mesh Runtime
echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Runtime resource ${COL_RES}"
kubectl  --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource-new


# wait for kind: PlatformMesh resource to become ready
echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for kind: PlatformMesh resource to become ready ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh.kubeconfig wait --namespace platform-mesh-system \
  --for=condition=Ready platformmesh \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh

wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system keycloak
kubectl --kubeconfig .secret/platform-mesh.kubeconfig delete pod -l pkg.crossplane.io/provider=provider-keycloak -n crossplane-system

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for ${DEPLOYMENT_TECH} resources ${COL_RES}"
wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system rebac-authz-webhook
wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system account-operator
wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system portal
wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system security-operator

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing KCP Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

if [ "$EXAMPLE_DATA" = true ]; then
  export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
  kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://localhost:8443/clusters/root"
  kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://localhost:8443/clusters/root:providers"
  kubectl apply -k $SCRIPT_DIR/../example-data/root/providers/httpbin-provider --server="https://localhost:8443/clusters/root:providers:httpbin-provider"
  unset KUBECONFIG

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  wait_for_deployment_resource .secret/platform-mesh.kubeconfig default api-syncagent

  wait_for_deployment_resource .secret/platform-mesh.kubeconfig default example-httpbin-provider

fi

echo -e "${COL}NOTE: Organization subdomains like <organization-name>.portal.localhost are resolved automatically by modern browsers. ${COL_RES}"
show_wsl_hosts_guidance

echo -e "${YELLOW}⚠️  WARNING: You need to add a hosts entry for every organization that is onboarded!${COL_RES}"
echo -e "${YELLOW}   Each organization will require its own subdomain entry in /etc/hosts${COL_RES}"
echo -e "${YELLOW}   Example: 127.0.0.1 <organization-name>.portal.localhost${COL_RES}"

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.localhost:8443 , any send emails can be received here: https://portal.localhost:8443/mailpit ${COL_RES}"

if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
