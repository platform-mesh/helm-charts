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

KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-3600s}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

# Helm requires an auth config file for OCI registries; create an empty one if absent.
echo '{"auths":{}}' > /tmp/helm-no-auth.json
 KINDEST_VERSION="kindest/node:v1.35.1"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
CONCURRENT=false
SHARDED=false
REMOTE=false
DEPLOYMENT_TECH="fluxcd"
ITERATE=false

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--concurrent] [--sharded] [--remote] [--deployment-tech=fluxcd|argocd] [--iterate] [--help]"
  echo ""
  echo "Options:"
  echo "  --prerelease       Deploy with locally built OCM components instead of released versions"
  echo "  --cached           Use local Docker registry mirrors for faster image pulls"
  echo "  --example-data     Install with example provider data (requires kubectl-kcp plugin)"
  echo "  --concurrent       Run prerelease chart builds in parallel instead of sequentially"
  echo "  --sharded          Deploy additional kcp shards"
  echo "  --remote           Use remote deployment mode with 2 kind clusters (infra + runtime)"
  echo "  --deployment-tech  Choose deployment technology: fluxcd or argocd (only with --remote). Default: fluxcd"
  echo "  --iterate          Skip infrastructure setup; rebuild and reapply the OCM component only (requires --prerelease)"
  echo "  --help             Show this help message"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --concurrent) CONCURRENT=true ;;
    --sharded) SHARDED=true ;;
    --remote) REMOTE=true ;;
    --deployment-tech=*)
      DEPLOYMENT_TECH="${1#*=}"
      if [ "$DEPLOYMENT_TECH" != "fluxcd" ] && [ "$DEPLOYMENT_TECH" != "argocd" ]; then
        echo "Error: --deployment-tech must be either 'fluxcd' or 'argocd'" >&2
        usage
      fi
      ;;
    --iterate) ITERATE=true ;;
    --help|-h) usage ;;
    --*) echo "Unknown option: $1" >&2; usage ;;
    *) echo "Ignoring positional arg: $1" ;;
  esac
  shift
done

# Export CONCURRENT and ITERATE for prerelease build scripts
export CONCURRENT
export ITERATE

if [ "$ITERATE" = true ] && [ "$PRERELEASE" = false ]; then
  echo -e "${RED}--iterate requires --prerelease${COL_RES}" >&2
  exit 1
fi

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

# Helper to apply kustomize with envsubst for RUNTIME_CLUSTER_IP substitution
kustomize_apply() {
  local kubeconfig_args=("$@")
  local kustomize_path="${kubeconfig_args[${#kubeconfig_args[@]}-1]}"
  unset 'kubeconfig_args[${#kubeconfig_args[@]}-1]'

  kubectl kustomize "$kustomize_path" | envsubst '$RUNTIME_CLUSTER_IP' | kubectl "${kubeconfig_args[@]}" apply -f -
}

# Helper to apply a file with envsubst for RUNTIME_CLUSTER_IP substitution
envsubst_apply() {
  local kubeconfig_args=("$@")
  local file_path="${kubeconfig_args[${#kubeconfig_args[@]}-1]}"
  unset 'kubeconfig_args[${#kubeconfig_args[@]}-1]'

  envsubst '$RUNTIME_CLUSTER_IP' < "$file_path" | kubectl "${kubeconfig_args[@]}" apply -f -
}

# Remote-only helper functions

install_fluxcd() {
  local kubeconfig=$1
  local concurrent=$2
  local namespace="flux-system"

  echo -e "${COL}[$(date '+%H:%M:%S')] Installing FluxCD ${COL_RES}"
  HELM_REGISTRY_CONFIG=/tmp/helm-no-auth.json helm upgrade --kubeconfig "$kubeconfig" -i -n "$namespace" --create-namespace flux oci://ghcr.io/fluxcd-community/charts/flux2 \
    --version 2.17.2 \
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
  KUBECONFIG=.secret/platform-mesh-infra.kubeconfig argocd login --core --kube-context kind-platform-mesh-infra
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig \
    config set-context kind-platform-mesh-infra --namespace=argocd
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
  CLUSTER_SECRET_FILE=".secret/platform-mesh-cluster-secret.yml"
  cp local-setup/kustomize/base/argocd-cluster-secret/platform-mesh-cluster-secret.yml "$CLUSTER_SECRET_FILE"
  yq -i '
    .stringData.config = (strenv(CERTCONFIG) + "\n")
    | .stringData.config style="literal"
  ' "$CLUSTER_SECRET_FILE"
  envsubst_apply --kubeconfig .secret/platform-mesh-infra.kubeconfig "$CLUSTER_SECRET_FILE"
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
    echo -e "${RED}[$(date '+%H:%M:%S')] Timed out waiting for ArgoCD Application ${namespace}/${resource_name} to become Healthy and Synced${COL_RES}" >&2
    exit 1
  fi
}

###############################################################################
# Common initialization
###############################################################################

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Using deployment technology: ${DEPLOYMENT_TECH} ${COL_RES}"
fi

if [ "$ITERATE" = true ]; then
  kind export kubeconfig --name platform-mesh
  if [ "$REMOTE" = true ]; then
    kind export kubeconfig --name platform-mesh --kubeconfig=.secret/platform-mesh.kubeconfig
    kind export kubeconfig --name platform-mesh-infra --kubeconfig=.secret/platform-mesh-infra.kubeconfig
  fi
else

  check_wsl_compatibility
  run_environment_checks

  if [ "$CACHED" = true ]; then
    setup_registry_proxies
  fi

  ###############################################################################
  # Generate certificates
  ###############################################################################

  mkdir -p $SCRIPT_DIR/certs
  $MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "localhost" "*.localhost" "portal.localhost" "*.portal.localhost" "*.services.portal.localhost" "oci-registry-docker-registry.registry.svc.cluster.local" 2>/dev/null
  cat "$($MKCERT_CMD -CAROOT)/rootCA.pem" > $SCRIPT_DIR/certs/ca.crt

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
  fi

fi # end of infrastructure setup (skipped when --iterate)

# Kubeconfig args for kubectl targeting the runtime cluster (empty for local)
RUNTIME_KC=()
if [ "$REMOTE" = true ]; then
  RUNTIME_KC=(--kubeconfig .secret/platform-mesh.kubeconfig)
fi

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

  # Run post-flux hook if it exists (Flux is ready at this point)
  if [ -f "$SCRIPT_DIR/post-flux-hook.sh" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running post-flux hook ${COL_RES}"
    source "$SCRIPT_DIR/post-flux-hook.sh"
  fi
fi

###############################################################################
# Install KRO / OCM
###############################################################################

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Install OCM, namespaces and KRO on infra cluster ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/kro

  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT ocm-k8s-toolkit
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT kro

  echo -e "${COL}[$(date '+%H:%M:%S')] Install OCM and namespaces on runtime cluster ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit

  kubectl --kubeconfig .secret/platform-mesh.kubeconfig wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT ocm-k8s-toolkit
else
  echo -e "${COL}[$(date '+%H:%M:%S')] Install KRO and OCM ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/base

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT kro

  kubectl wait --namespace default \
    --for=condition=Ready helmreleases \
    --timeout=$KUBECTL_WAIT_TIMEOUT ocm-k8s-toolkit

  echo -e "${COL}[$(date '+%H:%M:%S')] Creating necessary secrets ${COL_RES}"
  create_domain_secrets

  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"
  kubectl apply -k $SCRIPT_DIR/../kustomize/base/rgd
  kubectl wait --namespace default \
    --for=condition=Ready resourcegraphdefinition \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator
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

# For non-remote: wait for PlatformMeshOperator
if [ "$REMOTE" != true ]; then
  kubectl wait --namespace platform-mesh-system \
    --for=condition=Ready PlatformMeshOperator \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator
  kubectl wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=$KUBECTL_WAIT_TIMEOUT
fi

###############################################################################
# Remote: namespace + kubeconfig sharing between clusters
###############################################################################

if [ "$REMOTE" = true ]; then
  # Add platform-mesh kubeconfig to the infra cluster as a secret
  cp .secret/platform-mesh.kubeconfig .secret/platform-mesh.kubeconfig.tmp
  export RUNTIME_CLUSTER_IP=$(${CONTAINER_RUNTIME} inspect platform-mesh-control-plane | jq '.[0].NetworkSettings.Networks.kind.IPAddress' -r)
  echo -e "${COL}[$(date '+%H:%M:%S')] Runtime cluster IP: ${RUNTIME_CLUSTER_IP} ${COL_RES}"
  kubectl config set-cluster kind-platform-mesh \
    --server=https://$RUNTIME_CLUSTER_IP:6443 \
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
kubectl create secret generic keycloak-admin -n platform-mesh-system --from-literal=secret=admin --dry-run=client -o yaml | kubectl "${RUNTIME_KC[@]}" apply -f -

create_domain_secrets "${RUNTIME_KC[@]}"

###############################################################################
# Remote: CRDs, port-fixer, RGD setup
###############################################################################

if [ "$REMOTE" = true ]; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh CRDs ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/platform-mesh-operator-crds
  sleep 5
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=120s

  echo -e "${COL}[$(date '+%H:%M:%S')] Install port-fixer on platform-mesh cluster ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/port-fixer

  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/namespaces

  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator RGD on infra cluster ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/rgd
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --namespace default \
    --for=condition=Ready resourcegraphdefinition \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator
fi

###############################################################################
# Install Platform-Mesh resource overlays
###############################################################################

if [ "$REMOTE" = true ]; then
  if [ "$PRERELEASE" = true ]; then
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
  elif [ "$EXAMPLE_DATA" = true ]; then
    # Apply default profile to runtime cluster
    envsubst_apply --kubeconfig .secret/platform-mesh.kubeconfig $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}/default-profile.yaml
    # Apply example-httpbin-provider resources to INFRA cluster (targeting runtime)
    if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
      kustomize_apply --kubeconfig .secret/platform-mesh-infra.kubeconfig $SCRIPT_DIR/../kustomize/components/example-httpbin-provider-argocd
    else
      kustomize_apply --kubeconfig .secret/platform-mesh-infra.kubeconfig $SCRIPT_DIR/../kustomize/components/example-httpbin-provider
    fi
  else
    kustomize_apply --kubeconfig .secret/platform-mesh.kubeconfig $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}
  fi

  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"

  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    setup_argocd
    # Reset namespace context back to default after ArgoCD setup (which sets it to argocd)
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig \
      config set-context kind-platform-mesh-infra --namespace=default
  fi

  kustomize_apply --kubeconfig .secret/platform-mesh-infra.kubeconfig $SCRIPT_DIR/../kustomize/overlays/infra

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for Platform-Mesh Operator ${COL_RES}"
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait \
    --namespace platform-mesh-system \
    --for=condition=Ready PlatformMeshOperator \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh-operator || {
    # OCM digest mismatch may have prevented kro from deploying pm-operator.
    # Resolve chart/image via OCM CLI and deploy directly via FluxCD.
    echo -e "${COL}[$(date '+%H:%M:%S')] OCM rescue: deploying pm-operator directly via FluxCD ${COL_RES}"
    OCM_VER=$(kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig \
      get component.delivery.ocm.software platform-mesh -n platform-mesh-system \
      -o jsonpath='{.status.component.version}' 2>/dev/null || true)
    [ -z "$OCM_VER" ] && OCM_VER=$(grep "semver:" "$SCRIPT_DIR/../kustomize/components/ocm/component.yaml" | awk '{print $2}')
    PM_OP_CHART_OCI=$(./bin/ocm get resources --repo ghcr.io/platform-mesh \
      "github.com/platform-mesh/platform-mesh:${OCM_VER}" chart --recursive -o yaml 2>/dev/null | \
      awk '/helm-charts\/platform-mesh-operator:[0-9]/{found=1} found && /imageReference:/{print $2; exit}')
    export PM_OP_IMAGE_TAG=$(./bin/ocm get resources --repo ghcr.io/platform-mesh \
      "github.com/platform-mesh/platform-mesh:${OCM_VER}" image --recursive -o yaml 2>/dev/null | \
      awk '/images\/platform-mesh-operator:/{found=1} found && /^  version:/{print $2; exit}')
    if [ -z "$PM_OP_CHART_OCI" ] || [ -z "$PM_OP_IMAGE_TAG" ]; then
      echo -e "\033[91m[$(date '+%H:%M:%S')] Could not resolve pm-operator chart/image via OCM CLI - aborting\033[0m"
      exit 1
    fi
    export PM_OP_CHART_URL="oci://$(echo "$PM_OP_CHART_OCI" | cut -d: -f1)"
    export PM_OP_CHART_TAG="$(echo "$PM_OP_CHART_OCI" | cut -d: -f2)"
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig delete \
      platformmeshoperator platform-mesh-operator -n platform-mesh-system --wait=false 2>/dev/null || true
    sleep 10
    kubectl kustomize "$SCRIPT_DIR/../kustomize/components/platform-mesh-operator-fluxcd" | \
      envsubst '${PM_OP_CHART_URL}${PM_OP_CHART_TAG}${PM_OP_IMAGE_TAG}${RUNTIME_CLUSTER_IP}' | \
      kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f -
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait \
      --namespace platform-mesh-system \
      --for=condition=Ready helmrelease platform-mesh-operator \
      --timeout=$KUBECTL_WAIT_TIMEOUT
  }
  kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig wait --for=condition=Established crd/platformmeshes.core.platform-mesh.io --timeout=$KUBECTL_WAIT_TIMEOUT

  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/runtime

  # Re-apply Platform-Mesh resource after operator setup
  echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Runtime resource ${COL_RES}"
  if [ "$PRERELEASE" = true ]; then
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
  elif [ "$EXAMPLE_DATA" = true ]; then
    # Apply default profile and example-data (PlatformMesh patch) to runtime cluster
    envsubst_apply --kubeconfig .secret/platform-mesh.kubeconfig $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}/default-profile.yaml
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
    # Apply example-httpbin-provider resources to INFRA cluster (targeting runtime)
    if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
      kustomize_apply --kubeconfig .secret/platform-mesh-infra.kubeconfig $SCRIPT_DIR/../kustomize/components/example-httpbin-provider-argocd
    else
      kustomize_apply --kubeconfig .secret/platform-mesh-infra.kubeconfig $SCRIPT_DIR/../kustomize/components/example-httpbin-provider
    fi
  else
    kustomize_apply --kubeconfig .secret/platform-mesh.kubeconfig $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}
  fi

  # Pre-install cnpg-operator CRDs on runtime cluster so ArgoCD's infra Application doesn't fail
  # trying to create postgresql.cnpg.io resources before the CRDs exist.
  # ArgoCD doesn't enforce sync-wave ordering across independent Applications, so infra may sync
  # before cnpg-operator finishes installing. ServerSideApply=true on cnpg-operator handles the
  # large-CRD annotation limit, but the race still requires cnpg CRDs to be present first.
  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Pre-installing cnpg-operator CRDs on runtime cluster ${COL_RES}"
    CNPG_ELAPSED=0
    CNPG_VERSION=""
    while [ $CNPG_ELAPSED -lt 300 ]; do
      _raw=$(kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig \
        get application cnpg-operator -n platform-mesh-system \
        -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "")
      # Only accept a real semver (x.y.z…); reject placeholder strings
      if echo "$_raw" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]'; then
        CNPG_VERSION="$_raw"
        break
      fi
      sleep 5
      CNPG_ELAPSED=$((CNPG_ELAPSED + 5))
    done
    CNPG_VERSION="${CNPG_VERSION:-0.28.0}"
    # cert-manager's ValidatingWebhookConfiguration (failurePolicy=Fail) is registered before
    # its pod starts; any resource creation during that window is rejected, blocking CNPG install.
    kubectl --kubeconfig .secret/platform-mesh.kubeconfig \
      wait deployment cert-manager-webhook -n platform-mesh-system \
      --for=condition=Available --timeout=120s > /dev/null 2>&1 || true
    _cnpg_install_err=$(HELM_REGISTRY_CONFIG=/tmp/helm-no-auth.json helm upgrade -i cnpg-operator \
      oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg \
      --version "${CNPG_VERSION}" \
      --namespace platform-mesh-system \
      --create-namespace \
      --kubeconfig .secret/platform-mesh.kubeconfig 2>&1) || {
      echo -e "${RED}[$(date '+%H:%M:%S')] CNPG pre-install failed, retrying: ${_cnpg_install_err} ${COL_RES}"
      sleep 10
      HELM_REGISTRY_CONFIG=/tmp/helm-no-auth.json helm upgrade -i cnpg-operator \
        oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg \
        --version "${CNPG_VERSION}" \
        --namespace platform-mesh-system \
        --create-namespace \
        --kubeconfig .secret/platform-mesh.kubeconfig > /dev/null 2>&1 || true
    }

    kubectl --kubeconfig .secret/platform-mesh.kubeconfig \
      wait deployment cnpg-operator-cloudnative-pg \
      -n platform-mesh-system \
      --for=condition=Available \
      --timeout=120s > /dev/null 2>&1 || true
  fi

else
  # Apply PlatformMesh resource: use hook if available, otherwise use default overlay logic
  if [ -f "$SCRIPT_DIR/platform-mesh-resource-hook.sh" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running platform-mesh-resource hook ${COL_RES}"
    source "$SCRIPT_DIR/platform-mesh-resource-hook.sh"
  elif [ "$PRERELEASE" = true ]; then
    if [ "$EXAMPLE_DATA" = true ]; then
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease with example-data) ${COL_RES}"
      if [ "$SHARDED" = true ]; then
        kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease-sharded
      else
        kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
      fi
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
    else
      if [ "$SHARDED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease sharded) ${COL_RES}"
        kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease-sharded
      else
        echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (prerelease) ${COL_RES}"
        kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
      fi
    fi
  else
    if [ "$SHARDED" = true ]; then
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh (sharded) ${COL_RES}"
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-sharded
    else
      echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh ${COL_RES}"
      kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource
    fi
    if [ "$EXAMPLE_DATA" = true ]; then
      if [ "$SHARDED" = true ]; then
        kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data-sharded
      else
        kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
      fi
    fi
  fi
fi

###############################################################################
# Wait for PlatformMesh resource to become ready
###############################################################################

echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for kind: PlatformMesh resource to become ready ${COL_RES}"
# Rescue helper: patch *-chart OCM Resources on the RUNTIME cluster whose status is stuck in
# digest mismatch (CI republishes chart components with the same version tag, invalidating digests
# recorded in the parent component). The OCM k8s controller cannot bypass this check, but the OCI
# URL is still valid — we derive it from the error message and inject it directly into the Resource
# status so pm-operator can read it and create the deployment objects (HelmReleases / Applications).
_rescue_chart_resources() {
  local _kubeconfig="$1"
  local _failing
  _failing=$(kubectl --kubeconfig "$_kubeconfig" \
    get resources.delivery.ocm.software -n platform-mesh-system -o json 2>/dev/null | \
    jq -r '.items[] |
      select(.metadata.name | endswith("-chart")) |
      select(any(.status.conditions[]?; .type=="Ready" and .status=="False")) |
      (.metadata.name | rtrimstr("-chart")) as $chart |
      ((.status.conditions[] | select(.type=="Ready") | .message) | split(":")[1] | select(. != null and (test("^[0-9]") or test("^v[0-9]")))) as $ver |
      .metadata.name + "|ghcr.io/platform-mesh/helm-charts/" + $chart + ":" + $ver' 2>/dev/null || true)
  [ -z "$_failing" ] && return 0
  echo -e "${COL}[$(date '+%H:%M:%S')] OCM digest mismatch on runtime cluster - patching chart Resource statuses ${COL_RES}"
  kubectl --kubeconfig "$_kubeconfig" scale deployment \
    -n ocm-system ocm-k8s-toolkit-controller-manager --replicas=0 2>/dev/null || true
  sleep 5
  while IFS='|' read -r _res _oci; do
    [ -z "$_res" ] && continue
    _ver="${_oci##*:}"
    _ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    kubectl --kubeconfig "$_kubeconfig" \
      patch resource.delivery.ocm.software "$_res" -n platform-mesh-system \
      --subresource=status --type=merge \
      -p "{\"status\":{\"conditions\":[{\"lastTransitionTime\":\"${_ts}\",\"message\":\"Applied version ${_ver}\",\"reason\":\"Succeeded\",\"status\":\"True\",\"type\":\"Ready\",\"observedGeneration\":1}],\"observedGeneration\":1,\"resource\":{\"access\":{\"imageReference\":\"${_oci}\",\"type\":\"ociArtifact\"},\"name\":\"chart\",\"type\":\"helmChart\",\"version\":\"${_ver}\"}}}" 2>/dev/null || true
    echo -e "${COL}[$(date '+%H:%M:%S')] Patched ${_res} → ${_oci} ${COL_RES}"
  done <<< "$_failing"
  sleep 60
  kubectl --kubeconfig "$_kubeconfig" scale deployment \
    -n ocm-system ocm-k8s-toolkit-controller-manager --replicas=1 2>/dev/null || true
}
if [ "$REMOTE" = true ] && [ "$DEPLOYMENT_TECH" = "fluxcd" ]; then
  # On fresh clusters, large images can exceed the 15m Helm install timeout, leaving HelmReleases
  # in a Stalled/RetriesExceeded state that blocks pm-operator's WaitSubroutine. Also rescues
  # OCM digest mismatch on the runtime cluster (CI republishes charts with the same version tag).
  # Use real-time deadline so rescue's internal sleep doesn't silently consume the budget.
  total_timeout="${KUBECTL_WAIT_TIMEOUT%s}"
  deadline=$(( $(date +%s) + total_timeout ))
  platformmesh_ready=false
  while [ "$(date +%s)" -lt "$deadline" ]; do
    remaining=$(( deadline - $(date +%s) ))
    wait_secs=$(( remaining < 60 ? remaining : 60 ))
    if [ "$wait_secs" -le 0 ]; then break; fi
    if kubectl "${RUNTIME_KC[@]}" wait --namespace platform-mesh-system \
        --for=condition=Ready platformmesh --timeout="${wait_secs}s" platform-mesh 2>/dev/null; then
      platformmesh_ready=true
      break
    fi
    stalled=$(kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig \
      get helmreleases -n platform-mesh-system -o json 2>/dev/null | \
      jq -r '.items[] | select(.status.conditions[]? | select(.type=="Stalled" and .status=="True")) | .metadata.name' 2>/dev/null || true)
    if [ -n "$stalled" ]; then
      for hr in $stalled; do
        echo -e "${COL}[$(date '+%H:%M:%S')] Rescuing stalled HelmRelease: $hr ${COL_RES}"
        kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig patch helmrelease \
          -n platform-mesh-system "$hr" --type=merge \
          -p '{"spec":{"install":{"remediation":{"retries":-1}},"upgrade":{"remediation":{"retries":-1}}}}' 2>/dev/null || true
      done
    fi
    _rescue_chart_resources .secret/platform-mesh.kubeconfig
  done
  if [ "$platformmesh_ready" != "true" ]; then
    echo "error: timed out waiting for the condition on platformmeshes/platform-mesh"
    exit 1
  fi
elif [ "$REMOTE" = true ] && [ "$DEPLOYMENT_TECH" = "argocd" ]; then
  # Poll while rescuing OCM *-chart Resources on the runtime cluster stuck in digest mismatch.
  # Use real-time deadline so rescue's internal sleep doesn't silently consume the budget.
  total_timeout="${KUBECTL_WAIT_TIMEOUT%s}"
  deadline=$(( $(date +%s) + total_timeout ))
  platformmesh_ready=false
  while [ "$(date +%s)" -lt "$deadline" ]; do
    remaining=$(( deadline - $(date +%s) ))
    wait_secs=$(( remaining < 60 ? remaining : 60 ))
    if [ "$wait_secs" -le 0 ]; then break; fi
    if kubectl "${RUNTIME_KC[@]}" wait --namespace platform-mesh-system \
        --for=condition=Ready platformmesh --timeout="${wait_secs}s" platform-mesh 2>/dev/null; then
      platformmesh_ready=true
      break
    fi
    _rescue_chart_resources .secret/platform-mesh.kubeconfig
  done
  if [ "$platformmesh_ready" != "true" ]; then
    echo "error: timed out waiting for the condition on platformmeshes/platform-mesh"
    exit 1
  fi
else
  kubectl "${RUNTIME_KC[@]}" wait --namespace platform-mesh-system \
    --for=condition=Ready platformmesh \
    --timeout=$KUBECTL_WAIT_TIMEOUT platform-mesh
fi

###############################################################################
# Remote: post-install waits
###############################################################################

if [ "$REMOTE" = true ]; then
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

# Run post-platform-mesh hook if it exists (PlatformMesh is ready, kcp is accessible)
if [ -f "$SCRIPT_DIR/post-platform-mesh-hook.sh" ]; then
    echo -e "${COL}[$(date '+%H:%M:%S')] Running post-platform-mesh hook ${COL_RES}"
    KCP_KUBECONFIG="$(pwd)/.secret/kcp/admin.kubeconfig" source "$SCRIPT_DIR/post-platform-mesh-hook.sh"
fi

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
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl apply -k $SCRIPT_DIR/../example-data/root/orgs --server="https://localhost:8443/clusters/root:orgs"

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  if [ "$REMOTE" = true ]; then
    # Resources are on infra cluster, targeting runtime cluster
    if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
      wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig argocd api-syncagent
      wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig argocd example-httpbin-provider
    else
      wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig default api-syncagent
      wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig default example-httpbin-provider
    fi
  else
    kubectl wait --namespace platform-mesh-system \
      --for=condition=Ready helmreleases \
      --timeout=$KUBECTL_WAIT_TIMEOUT api-syncagent

    kubectl wait --namespace platform-mesh-system \
      --for=condition=Ready helmreleases \
      --timeout=$KUBECTL_WAIT_TIMEOUT example-httpbin-provider
  fi
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Installing observability stack ${COL_RES}"
helm dependency update "$SCRIPT_DIR/../../charts/observability" > /dev/null 2>&1
kubectl create namespace observability --dry-run=client -o yaml | kubectl "${RUNTIME_KC[@]}" apply -f -
_obs_err=$(helm upgrade --install observability "$SCRIPT_DIR/../../charts/observability" \
  "${RUNTIME_KC[@]}" -n observability \
  --set prometheus.server.persistentVolume.enabled=false \
  --wait --timeout=10m 2>&1) || {
  echo -e "${RED}[$(date '+%H:%M:%S')] Observability install failed, retrying: ${_obs_err} ${COL_RES}"
  # The OTel operator registers its webhook before the pod is ready (failurePolicy=Fail).
  # Wait for it to be Available before retrying so the post-install hook can succeed.
  kubectl "${RUNTIME_KC[@]}" wait deployment observability-opentelemetry-operator \
    -n observability --for=condition=Available --timeout=120s > /dev/null 2>&1 || true
  helm upgrade --install observability "$SCRIPT_DIR/../../charts/observability" \
    "${RUNTIME_KC[@]}" -n observability \
    --set prometheus.server.persistentVolume.enabled=false \
    --wait --timeout=10m > /dev/null 2>&1 || true
}

echo -e "${COL}[$(date '+%H:%M:%S')] Verifying backend resources ${COL_RES}"
WAIT_TIMEOUT=120s "$SCRIPT_DIR/check-backend-resources.sh"

echo -e "${YELLOW}⚠️  NOTE: Organization subdomains like <organization-name>.portal.localhost are resolved automatically by modern browsers.${COL_RES}"
echo -e "${YELLOW}   No /etc/hosts entries are needed for browser access.${COL_RES}"
show_wsl_hosts_guidance

echo -e "${COL}Once kcp is up and running, run '\033[0;32mexport KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig\033[0m' to gain access to the root workspace.${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Saving kcp root CA certificate ${COL_RES}"
kubectl "${RUNTIME_KC[@]}" -n platform-mesh-system get secret root-ca -oyaml | yq '.data["ca.crt"]' | base64 -d > $SCRIPT_DIR/certs/root-ca.crt

echo -e "${YELLOW}⚠️  Add the following entry to /etc/hosts if not already present:${COL_RES}"
echo 'echo "127.0.0.1 kcp.root.localhost" | sudo tee -a /etc/hosts'

echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}[$(date '+%H:%M:%S')] Installation Complete ${RED}♥${COL} !${COL_RES}"
echo -e "${COL}-------------------------------------${COL_RES}"
echo -e "${COL}You can access the onboarding portal at: https://portal.localhost:8443 ${COL_RES}"


if ! git diff --quiet $SCRIPT_DIR/../kustomize/components/platform-mesh-operator-resource/platform-mesh.yaml; then
  echo -e "${COL}[$(date '+%H:%M:%S')] Detected changes in platform-mesh-operator-resource/platform-mesh.yaml${COL_RES}"
  echo -e "${COL}[$(date '+%H:%M:%S')] You may need to run task local-setup:iterate to apply them.${COL_RES}"
fi

exit 0
