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
 KINDEST_VERSION="kindest/node:v1.35.0"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
CONCURRENT=false
REMOTE=false
DEPLOYMENT_TECH="fluxcd"

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--concurrent] [--remote] [--deployment-tech=fluxcd|argocd] [--help]"
  echo ""
  echo "Options:"
  echo "  --prerelease       Deploy with locally built OCM components instead of released versions"
  echo "  --cached           Use local Docker registry mirrors for faster image pulls"
  echo "  --example-data     Install with example provider data (requires kubectl-kcp plugin)"
  echo "  --concurrent       Run prerelease chart builds in parallel instead of sequentially"
  echo "  --remote           Use remote deployment mode with 2 kind clusters (infra + runtime)"
  echo "  --deployment-tech  Choose deployment technology: fluxcd or argocd (only with --remote). Default: fluxcd"
  echo "  --help             Show this help message"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --concurrent) CONCURRENT=true ;;
    --remote) REMOTE=true ;;
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

# Export CONCURRENT for prerelease build scripts
export CONCURRENT

# Source compatibility and environment checks
source "$SCRIPT_DIR/check-wsl-compatibility.sh"
source "$SCRIPT_DIR/check-environment.sh"
source "$SCRIPT_DIR/setup-registry-proxies.sh"
source "$SCRIPT_DIR/setup-prerelease.sh"

###############################################################################
# Helper functions
###############################################################################

create_kind_cluster() {
  local cluster_name=$1
  local config_file=$2
  local cached_config_file=$3
  local use_quiet=${4:-true}

  if [ -d "$SCRIPT_DIR/certs" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Clearing existing certs directory ${COL_RES}"
    rm -rf "$SCRIPT_DIR/certs"
  fi
  $SCRIPT_DIR/../scripts/gen-certs.sh

  local quiet_flag=""
  if [ "$use_quiet" = true ]; then
    quiet_flag="--quiet"
    if [ "$DEBUG" = "true" ]; then
      quiet_flag=""
    fi
  fi

  if [ "$CACHED" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${cluster_name} with cached images ${COL_RES}"
    local temp_config=$(mktemp)
    local certs_dir=$(cd "$SCRIPT_DIR/../kind/containerd-certs.d" && pwd)
    sed "s|./containerd-certs.d|${certs_dir}|" "$SCRIPT_DIR/../kind/${cached_config_file}" > "$temp_config"
    kind create cluster --config "$temp_config" --name "$cluster_name" --image=$KINDEST_VERSION $quiet_flag
    rm -f "$temp_config"
  else
    echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${cluster_name} ${COL_RES}"
    kind create cluster --config "$SCRIPT_DIR/../kind/${config_file}" --name "$cluster_name" --image=$KINDEST_VERSION $quiet_flag
  fi
}

create_domain_secrets() {
  local kc=("$@")

  kubectl create secret generic domain-certificate -n default \
    --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
    --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
    --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
    --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl "${kc[@]}" apply -f -

  kubectl create secret generic domain-certificate -n platform-mesh-system \
    --from-file=tls.crt=$SCRIPT_DIR/certs/cert.crt \
    --from-file=tls.key=$SCRIPT_DIR/certs/cert.key \
    --from-file=ca.crt=$SCRIPT_DIR/certs/ca.crt \
    --type=kubernetes.io/tls --dry-run=client -oyaml | kubectl "${kc[@]}" apply -f -

  kubectl create secret generic domain-certificate-ca -n platform-mesh-system \
    --from-file=tls.crt=$SCRIPT_DIR/certs/ca.crt --dry-run=client -oyaml | kubectl "${kc[@]}" apply -f -
}

# Remote-only helper functions

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
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig delete pod -n argocd -l app.kubernetes.io/instance=argo-cd

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for ArgoCD to restart after configuration update ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace argocd \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT argo-cd-argocd-repo-server > /dev/null 2>&1
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace argocd \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT argo-cd-argocd-server > /dev/null 2>&1
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace argocd \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT argo-cd-argocd-applicationset-controller > /dev/null 2>&1
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

###############################################################################
# Common initialization
###############################################################################

check_wsl_compatibility
run_environment_checks

if [ "$CACHED" = true ]; then
  setup_registry_proxies
fi

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Using deployment technology: ${DEPLOYMENT_TECH} ${COL_RES}"
fi

###############################################################################
# Create kind cluster(s)
###############################################################################

if ! check_kind_cluster; then
  create_kind_cluster platform-mesh kind-config.yaml kind-config-cached.yaml true
fi

if [ "$REMOTE" = true ]; then
  kind export kubeconfig --name platform-mesh --kubeconfig=.secret/platform-mesh.kubeconfig

  if ! check_kind_infra_cluster; then
    create_kind_cluster platform-mesh-infra kind-config-infra.yaml kind-config-infra-cached.yaml false
    kind export kubeconfig --name platform-mesh-infra --kubeconfig=.secret/platform-mesh-infra.kubeconfig
  fi

  ### Remove this when operator is published
  kind load docker-image ghcr.io/platform-mesh/platform-mesh-operator:v0.27.0-rc.11 --name platform-mesh-infra
fi

# Kubeconfig args for kubectl targeting the runtime cluster (empty for local)
RUNTIME_KC=()
if [ "$REMOTE" = true ]; then
  RUNTIME_KC=(--kubeconfig .secret/platform-mesh.kubeconfig)
fi

###############################################################################
# Generate certificates
###############################################################################

mkdir -p $SCRIPT_DIR/certs
if [ "$REMOTE" = true ]; then
  MKCERT_CMD="bin/mkcert"
fi
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "localhost" "*.localhost" "portal.localhost" "*.portal.localhost" "*.services.portal.localhost" "oci-registry-docker-registry.registry.svc.cluster.local" 2>/dev/null
cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

# Local: load custom images if hook script exists
if [ "$REMOTE" != true ] && [ -f "$SCRIPT_DIR/load-custom-images.sh" ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Loading custom images ${COL_RES}"
  source "$SCRIPT_DIR/load-custom-images.sh"
fi

###############################################################################
# Install deployment tooling (Flux / ArgoCD)
###############################################################################

if [ "$REMOTE" = true ]; then
  install_fluxcd .secret/platform-mesh-infra.kubeconfig 50
  install_fluxcd .secret/platform-mesh.kubeconfig 10

  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    install_argocd .secret/platform-mesh-infra.kubeconfig
    install_argocd .secret/platform-mesh.kubeconfig
  fi
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Installing flux ${COL_RES}"
  helm upgrade -i -n flux-system --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
    --version 2.17.2 \
    --set imageAutomationController.create=false \
    --set imageReflectionController.create=false \
    --set notificationController.create=false \
    --set-json 'helmController.container.additionalArgs=["--concurrent=50"]' \
    --set-json 'sourceController.container.additionalArgs=["--requeue-dependency=5s"]' > /dev/null 2>&1

  kubectl wait --namespace flux-system \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT helm-controller > /dev/null 2>&1
  kubectl wait --namespace flux-system \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT source-controller > /dev/null 2>&1
  kubectl wait --namespace flux-system \
    --for=condition=available deployment \
    --timeout=$KUBECTL_WAIT_TIMEOUT kustomize-controller > /dev/null 2>&1
fi

###############################################################################
# Install base components (OCM / KRO)
###############################################################################

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Install OCM ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Install KRO and OCM ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/base

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT kro
fi

###############################################################################
# Prerelease / OCM version setup
###############################################################################

if [ "$PRERELEASE" = true ]; then
  if [ "$REMOTE" = true ]; then
    export KUBECONFIG=.secret/platform-mesh.kubeconfig
  fi
  run_prerelease_setup
  if [ "$REMOTE" = true ]; then
    unset KUBECONFIG
  fi
else
  OCM_VERSION=$(yq '.spec.semver' "$SCRIPT_DIR/../kustomize/components/ocm/component.yaml")
  echo -e "${COL}[$(date '+%H:%M:%S')] Using OCM Component version: ${OCM_VERSION} ${COL_RES}"
  if [ "$REMOTE" != true ]; then
    kubectl apply -k "$SCRIPT_DIR/../kustomize/overlays/default"
  fi
fi

###############################################################################
# Remote: namespace + kubeconfig sharing between clusters
###############################################################################

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Creating namespaces ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces

  # Add platform-mesh kubeconfig to the infra cluster as a secret
  cp .secret/platform-mesh.kubeconfig .secret/platform-mesh.kubeconfig.tmp
  IP_ADDR=$(docker inspect platform-mesh-control-plane|jq '.[0] | .NetworkSettings | .Networks | .kind | .IPAddress' -r)
  kubectl config set-cluster kind-platform-mesh \
    --server=https://$IP_ADDR:6443 \
    --kubeconfig=.secret/platform-mesh.kubeconfig.tmp
  kubectl create secret generic platform-mesh-kubeconfig -n platform-mesh-system \
    --from-file=kubeconfig=.secret/platform-mesh.kubeconfig.tmp --dry-run=client -o yaml | kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f -
  kubectl create secret generic platform-mesh-kubeconfig -n default \
    --from-file=kubeconfig=.secret/platform-mesh.kubeconfig.tmp --dry-run=client -o yaml | kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f -
fi

###############################################################################
# Create secrets
###############################################################################

echo -e "${COL}[$(date '+%H:%M:%S')] Creating necessary secrets ${COL_RES}"

if [ "$REMOTE" = true ]; then
  kubectl create secret tls iam-authorization-webhook-webhook-ca -n platform-mesh-system --key $SCRIPT_DIR/../webhook-config/ca.key --cert $SCRIPT_DIR/../webhook-config/ca.crt --dry-run=client -o yaml | kubectl "${RUNTIME_KC[@]}" apply -f -
fi
#kubectl create secret tls iam-authorization-webhook-webhook-ca -n platform-mesh-system --key $SCRIPT_DIR/../webhook-config/ca.key --cert $SCRIPT_DIR/../webhook-config/ca.crt --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl "${RUNTIME_KC[@]}" apply -f -

create_domain_secrets "${RUNTIME_KC[@]}"

###############################################################################
# Local: Platform-Mesh Operator (RGD) setup
###############################################################################

if [ "$REMOTE" != true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/base/rgd
  kubectl wait --namespace default \
    --for=condition=Ready resourcegraphdefinition \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator

  # kind load image-archive image.tar --name platform-mesh
  # kind load docker-image ghcr.io/platform-mesh/platform-mesh-operator:v0.41.9 --name platform-mesh

  kubectl wait --namespace default \
    --for=condition=Ready PlatformMeshOperator \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator
  kubectl wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=$KUBECTL_WAIT_TIMEOUT
fi

###############################################################################
# Remote: CRDs, port-fixer, ArgoCD setup, infra/runtime overlays
###############################################################################

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh CRDs ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/platform-mesh-operator-crds
  sleep 5
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=120s

  echo -e "${COL}[$(date '+%H:%M:%S')] Install port-fixer on platform-mesh cluster ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/port-fixer

  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces
fi

###############################################################################
# Install Platform-Mesh resource overlays
###############################################################################

if [ "$REMOTE" = true ]; then
  if [ "$PRERELEASE" = true ]; then
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
  elif [ "$EXAMPLE_DATA" = true ]; then
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}/default-profile.yaml
    if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
      kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
      kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/example-httpbin-provider-argocd
    else
      kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
    fi
  else
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}
  fi

  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"

  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    setup_argocd
  fi

  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/infra
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/runtime

  # Re-apply Platform-Mesh Runtime resource after operator setup
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Runtime resource ${COL_RES}"
  if [ "$PRERELEASE" = true ]; then
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
  elif [ "$EXAMPLE_DATA" = true ]; then
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}/default-profile.yaml
    if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
      kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
      kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/example-httpbin-provider-argocd
    else
      kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
    fi
  else
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}
  fi
else
  if [ "$PRERELEASE" = true ]; then
    if [ "$EXAMPLE_DATA" = true ]; then
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease with example-data) ${COL_RES}"
      # TODO: Create example-data-prerelease overlay if needed
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
    else
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease) ${COL_RES}"
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
    fi
  elif [ "$EXAMPLE_DATA" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (with example-data) ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
  else
    echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh ${COL_RES}"
    kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource
  fi
fi

###############################################################################
# Wait for PlatformMesh resource to become ready
###############################################################################

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for kind: PlatformMesh resource to become ready ${COL_RES}"
kubectl "${RUNTIME_KC[@]}" wait --namespace platform-mesh-system \
  --for=condition=Ready platformmesh \
  --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh

###############################################################################
# Remote: post-install waits
###############################################################################

if [ "$REMOTE" = true ]; then
  wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system keycloak
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig delete pod -l pkg.crossplane.io/provider=provider-keycloak -n crossplane-system

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for ${DEPLOYMENT_TECH} resources ${COL_RES}"
  wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system rebac-authz-webhook
  wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system account-operator
  wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system portal
  wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig platform-mesh-system security-operator
fi

###############################################################################
# KCP admin kubeconfig
###############################################################################

echo -e "${COL}[$(date '+%H:%M:%S')] Preparing KCP Secrets for admin access ${COL_RES}"
$SCRIPT_DIR/createKcpAdminKubeconfig.sh

###############################################################################
# Example data
###############################################################################

if [ "$EXAMPLE_DATA" = true ]; then
  if [ "$REMOTE" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Applying example-data resources. ${COL_RES}"
  fi

  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://localhost:8443/clusters/root"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://localhost:8443/clusters/root:providers"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl apply -k $SCRIPT_DIR/../example-data/root/providers/httpbin-provider --server="https://localhost:8443/clusters/root:providers:httpbin-provider"

  if [ "$REMOTE" = true ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for httpbin-kubeconfig secret on runtime cluster ${COL_RES}"
    until kubectl --kubeconfig .secret/platform-mesh.kubeconfig get secret httpbin-kubeconfig -n example-httpbin-provider > /dev/null 2>&1; do
      sleep 2
    done

    echo -e "${COL}[$(date '+%H:%M:%S')] Updating httpbin-kubeconfig server URL on runtime cluster ${COL_RES}"
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig get secret httpbin-kubeconfig -n example-httpbin-provider -o jsonpath='{.data.kubeconfig}' \
      | base64 -d > .secret/httpbin-kubeconfig.tmp

    kubectl config set-cluster --kubeconfig=.secret/httpbin-kubeconfig.tmp \
      "$(kubectl config get-clusters --kubeconfig=.secret/httpbin-kubeconfig.tmp | tail -1)" \
      --server=https://localhost:8443/clusters/root:providers:httpbin-provider

    kubectl create secret generic httpbin-kubeconfig -n example-httpbin-provider \
      --from-file=kubeconfig=.secret/httpbin-kubeconfig.tmp --dry-run=client -o yaml \
      | kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f -

    rm -f .secret/httpbin-kubeconfig.tmp
  fi

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  if [ "$REMOTE" = true ]; then
    if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
      wait_for_deployment_resource .secret/platform-mesh.kubeconfig argocd api-syncagent
      wait_for_deployment_resource .secret/platform-mesh.kubeconfig argocd example-httpbin-provider
    else
      wait_for_deployment_resource .secret/platform-mesh.kubeconfig default api-syncagent
      wait_for_deployment_resource .secret/platform-mesh.kubeconfig default example-httpbin-provider
    fi
  else
    kubectl wait --namespace default \
      --for=condition=Ready helmreleases \
      --timeout=$KUBECTL_WAIT_TIMEOUT api-syncagent

    kubectl wait --namespace default \
      --for=condition=Ready helmreleases \
      --timeout=$KUBECTL_WAIT_TIMEOUT example-httpbin-provider
  fi
fi

###############################################################################
# Done
###############################################################################

echo -e "${YELLOW}⚠️  NOTE: Organization subdomains like <organization-name>.portal.localhost are resolved automatically by modern browsers.${COL_RES}"
echo -e "${YELLOW}   No /etc/hosts entries are needed for browser access.${COL_RES}"
show_wsl_hosts_guidance

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.localhost:8443 ${COL_RES}"

if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
