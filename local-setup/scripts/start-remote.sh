#!/bin/bash
# Remote deployment logic (2 kind clusters: infra + runtime)
# Sourced by start.sh when --remote is specified

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

    KIND_QUIET_FLAG="--quiet"
    if [ "$DEBUG" = "true" ]; then
        KIND_QUIET_FLAG=""
    fi

    if [ "$CACHED" = true ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster with cached images ${COL_RES}"

        # Create temporary kind config with absolute path for containerd certs
        TEMP_KIND_CONFIG=$(mktemp)
        CERTS_DIR=$(cd "$SCRIPT_DIR/../kind/containerd-certs.d" && pwd)
        sed "s|./containerd-certs.d|${CERTS_DIR}|" "$SCRIPT_DIR/../kind/kind-config-cached.yaml" > "$TEMP_KIND_CONFIG"

        kind create cluster --config "$TEMP_KIND_CONFIG" --name platform-mesh --image=$KINDEST_VERSION $KIND_QUIET_FLAG
        rm -f "$TEMP_KIND_CONFIG"
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] Creating kind cluster ${COL_RES}"
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config.yaml --name platform-mesh --image=$KINDEST_VERSION $KIND_QUIET_FLAG
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

        # Create temporary kind config with absolute path for containerd certs
        TEMP_KIND_CONFIG_INFRA=$(mktemp)
        CERTS_DIR=$(cd "$SCRIPT_DIR/../kind/containerd-certs.d" && pwd)
        sed "s|./containerd-certs.d|${CERTS_DIR}|" "$SCRIPT_DIR/../kind/kind-config-infra-cached.yaml" > "$TEMP_KIND_CONFIG_INFRA"

        kind create cluster --config "$TEMP_KIND_CONFIG_INFRA" --name platform-mesh-infra --image=$KINDEST_VERSION
        rm -f "$TEMP_KIND_CONFIG_INFRA"
    else
        kind create cluster --config $SCRIPT_DIR/../kind/kind-config-infra.yaml --name platform-mesh-infra --image=$KINDEST_VERSION
    fi
    kind export kubeconfig --name platform-mesh-infra --kubeconfig=.secret/platform-mesh-infra.kubeconfig

fi

### Remove this when operator is published
kind load docker-image ghcr.io/platform-mesh/platform-mesh-operator:v0.27.0-rc.11 --name platform-mesh-infra

MKCERT_CMD="bin/mkcert"
mkdir -p $SCRIPT_DIR/certs
$MKCERT_CMD -cert-file=$SCRIPT_DIR/certs/cert.crt -key-file=$SCRIPT_DIR/certs/cert.key "localhost" "*.localhost" "portal.localhost" "*.portal.localhost" "*.services.portal.localhost" "oci-registry-docker-registry.registry.svc.cluster.local" 2>/dev/null
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

echo -e "${COL}[$(date '+%H:%M:%S')] Install OCM ${COL_RES}"
kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit
kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/base/ocm-k8s-toolkit

if [ "$PRERELEASE" = true ]; then
  export KUBECONFIG=.secret/platform-mesh.kubeconfig
  run_prerelease_setup
  unset KUBECONFIG
else
  OCM_VERSION=$(yq '.spec.semver' "$SCRIPT_DIR/../kustomize/components/ocm/component.yaml")
  echo -e "${COL}[$(date '+%H:%M:%S')] Using OCM Component version: ${OCM_VERSION} ${COL_RES}"
fi

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
if [ "$PRERELEASE" = true ]; then
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
elif [ "$EXAMPLE_DATA" = true ]; then
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}/default-profile.yaml
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/example-httpbin-provider-argocd
  else
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/example-httpbin-provider
  fi
else
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}
fi

echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Operator ${COL_RES}"

if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
  setup_argocd
fi

kubectl  --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/infra
kubectl  --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/runtime

# Install Platform-Mesh Runtime
echo -e "${COL}[$(date '+%H:%M:%S')] Install Platform-Mesh Runtime resource ${COL_RES}"
if [ "$PRERELEASE" = true ]; then
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-prerelease
elif [ "$EXAMPLE_DATA" = true ]; then
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -f $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}/default-profile.yaml
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/example-data
  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/example-httpbin-provider-argocd
  else
    kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -k $SCRIPT_DIR/../kustomize/components/example-httpbin-provider
  fi
else
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig apply -k $SCRIPT_DIR/../kustomize/overlays/platform-mesh-resource-${DEPLOYMENT_TECH}
fi


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
  echo -e "${COL}[$(date '+%H:%M:%S')] Applying example-data resources. ${COL_RES}"

  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl create-workspace providers --type=root:providers --ignore-existing --server="https://localhost:8443/clusters/root"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl create-workspace httpbin-provider --type=root:provider --ignore-existing --server="https://localhost:8443/clusters/root:providers"
  KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig kubectl apply -k $SCRIPT_DIR/../example-data/root/providers/httpbin-provider --server="https://localhost:8443/clusters/root:providers:httpbin-provider"

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for httpbin-kubeconfig secret on runtime cluster ${COL_RES}"
  until kubectl --kubeconfig .secret/platform-mesh.kubeconfig get secret httpbin-kubeconfig -n example-httpbin-provider > /dev/null 2>&1; do
    sleep 2
  done

  echo -e "${COL}[$(date '+%H:%M:%S')] Transferring httpbin-kubeconfig to infra cluster ${COL_RES}"
  # Extract kubeconfig from runtime cluster secret, modify server URL, and apply to infra cluster
  kubectl --kubeconfig .secret/platform-mesh.kubeconfig get secret httpbin-kubeconfig -n example-httpbin-provider -o jsonpath='{.data.kubeconfig}' \
    | base64 -d > .secret/httpbin-kubeconfig.tmp

  # Update the server URL to point to the KCP workspace for httpbin-provider
  kubectl config set-cluster --kubeconfig=.secret/httpbin-kubeconfig.tmp \
    "$(kubectl config get-clusters --kubeconfig=.secret/httpbin-kubeconfig.tmp | tail -1)" \
    --server=https://localhost:8443/clusters/root:providers:httpbin-provider

  kubectl create secret generic httpbin-kubeconfig -n example-httpbin-provider \
    --from-file=kubeconfig=.secret/httpbin-kubeconfig.tmp --dry-run=client -o yaml \
    | kubectl --kubeconfig .secret/platform-mesh-infra.kubeconfig apply -f -

  rm -f .secret/httpbin-kubeconfig.tmp

  echo -e "${COL}[$(date '+%H:%M:%S')] Waiting for example provider ${COL_RES}"

  if [ "$DEPLOYMENT_TECH" = "argocd" ]; then
    wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig argocd api-syncagent
    wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig argocd example-httpbin-provider
  else
    wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig default api-syncagent
    wait_for_deployment_resource .secret/platform-mesh-infra.kubeconfig default example-httpbin-provider
  fi

fi

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
