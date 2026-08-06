#!/bin/bash

# OCM Build Component Script
# Main entry point for building the complete OCM prerelease component
# This script replaces the functionality of `task ocm:build`

set -e

if [ "${DEBUG}" = "true" ]; then
  set -x
fi

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helper scripts
source "$SCRIPT_DIR/ocm-setup.sh"
source "$SCRIPT_DIR/ocm-build-local-charts.sh"

# Configuration
LOCAL_BIN="${LOCAL_BIN:-$PROJECT_ROOT/bin}"
OCM_DIR="${OCM_DIR:-$PROJECT_ROOT/.ocm}"
COMPONENT_PRERELEASE_VERSION="${COMPONENT_PRERELEASE_VERSION:-1.0.0}"

# Remote registries
REMOTE_REGISTRY="${REMOTE_REGISTRY:-ghcr.io/platform-mesh}"
LOCAL_REGISTRY="${LOCAL_REGISTRY:-oci-registry-docker-registry.registry.svc.cluster.local}"

# List of local component names (for version resolution)
CUSTOM_LOCAL_COMPONENTS="account-operator,example-httpbin-operator,extension-manager-operator,iam-service,iam-ui,infra,keycloak-operator,kro-composition-operator,kubernetes-graphql-gateway,marketplace-ui,observability,platform-mesh-operator,platform-mesh-operator-components,platform-mesh-operator-infra-components,portal,rebac-authz-webhook,security-operator,terminal-controller-manager,virtual-workspaces"

# Fixed version overrides (empty by default)
FIXED_VERSION_PAIRS=""

# Color output (respect NO_COLOR env var)
if [ -z "$NO_COLOR" ]; then
    COL='\033[92m'
    RED='\033[91m'
    COL_RES='\033[0m'
else
    COL=''
    RED=''
    COL_RES=''
fi

# Get kubectl exec flags based on current TTY availability
# Must be called at point of use, not script init, because background jobs lose TTY
get_kubectl_exec_flags() {
    if [ -t 0 ]; then
        echo "-ti"
    else
        echo "-i"
    fi
}

# Update/download the component constructor template
update_constructor() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Preparing component-constructor-prerelease.yaml...${COL_RES}"

    cp "$OCM_DIR/component-constructor-aggregate.yaml" "$OCM_DIR/component-constructor-prerelease.yaml"

    # Rename the component from platform-mesh to prerelease
    sed 's/name:\ github.com\/platform-mesh\/platform-mesh/name:\ github.com\/platform-mesh\/prerelease/' \
        "$OCM_DIR/component-constructor-prerelease.yaml" > "$OCM_DIR/component-constructor-prerelease.yaml.tmp" \
        && mv "$OCM_DIR/component-constructor-prerelease.yaml.tmp" "$OCM_DIR/component-constructor-prerelease.yaml"

    # Strip only the gateway-api inline component: it uses 'type: github' which OCM v2 cannot
    # resolve locally. All other inline third-party components use 'type: ociArtifact' and
    # can be built directly from the constructor by v2.
    yq eval '.components |= map(select(.name != "github.com/kubernetes-sigs/gateway-api"))' \
        -i "$OCM_DIR/component-constructor-prerelease.yaml"

    # Strip componentReferences to components that v2 cannot resolve locally:
    # - keycloak: external component (github.com/platform-mesh/keycloak) not built locally
    #             and not defined inline in the aggregate constructor
    # gateway-api: inline component definition stripped above (type: github), but the componentReference
    #              is KEPT — the pre-built component is transferred from ghcr.io/platform-mesh into
    #              the CTF by transfer_gateway_api() before build_final_component() runs.
    # etcd-druid:  kept — its full dep tree is pre-populated in the CTF by transfer_from_cache().
    yq eval '.components[].componentReferences |= map(select(.name != "keycloak"))' \
        -i "$OCM_DIR/component-constructor-prerelease.yaml"

    echo -e "${COL}[$(date '+%H:%M:%S')] Component constructor updated${COL_RES}"
}

# Check if a component is local
is_local() {
    echo ",$CUSTOM_LOCAL_COMPONENTS," | grep -q ",$1,"
}

# Get local component version
get_component_version() {
    local short="$1"
    local component="$2"
    local chart_dir="$3"
    local env_var="$4"

    # 1. Check for fixed override
    for pair in $FIXED_VERSION_PAIRS; do
        local name="${pair%%:*}"
        local ver="${pair#*:}"
        if [ "$short" = "$name" ] && [ -n "$ver" ] && [ "$ver" != "$name" ]; then
            echo "Using FIXED override version for $short -> $ver"
            export "$env_var"="$ver"
            kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer component-version --recursive --copy-resources "ghcr.io/platform-mesh//$component:$ver" "https://$LOCAL_REGISTRY/platform-mesh"
            return 0
        fi
    done

    # 2. Check for local chart directory
    if is_local "$short" && [ -n "$chart_dir" ] && [ -f "$PROJECT_ROOT/$chart_dir/Chart.yaml" ]; then
        local val
        val=$(grep '^version:' "$PROJECT_ROOT/$chart_dir/Chart.yaml" | sed 's/^version: //')
        echo "Using LOCAL chartDir version for $short -> $val"
        export "$env_var"="$val"
        return 0
    fi

    echo "Trying to resolve non-local component $shart / $component"
    exit 1
}

# Get resource version from OCM
get_ocm_resource_version() {
    local component="$1"
    local query="$2"
    "$LOCAL_BIN/ocm" --config "$OCM_DIR/config" get resources "oci://ghcr.io/platform-mesh//$component" --latest -o json | jq -r "$query"
}

# Get component version from an external registry, probably might be deleted after platform-mesh component update
get_external_component_version() {
    local component="$1"
    local repo="$2"
    "$LOCAL_BIN/ocm" --config "$OCM_DIR/config" get component-version --latest "$repo//$component" -o json | jq -r '.items[0].component.version'
}

# poor mans persistence for heavy deps.
# Built for CI speedup, adjusted for our own good.
transfer_from_cache() {
    # etcd-druid
    local name="$1"
    # europe-docker.pkg.dev/gardener-project/releases//github.com/gardener/etcd-druid
    local ref="$2"
    # vA.B.C
    local ver="$3"

    local cache_dir="$OCM_DIR/cache/$name"
    local cluster_oci="$LOCAL_REGISTRY/platform-mesh"

    local cached_tag=""
    if [ -f "$cache_dir/artifact-index.json" ]; then
        cached_tag=$(jq -r '.artifacts[0].tag // ""' "$cache_dir/artifact-index.json" 2>/dev/null || echo "")
    fi

    if [ "$cached_tag" != "$ver" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] $name: cache miss (have '${cached_tag:-none}', want $ver), transferring${COL_RES}"
        rm -rf "$cache_dir"
        mkdir -p "$(dirname "$cache_dir")"
        "$LOCAL_BIN/ocm" --config "$OCM_DIR/config" transfer component-version \
            "$ref:$ver" "$cache_dir"
    fi

    local pod_path=".ocm/cache-$name"
    kubectl exec -i ocm-transfer-pod -- rm -rf "$pod_path"
    kubectl exec -i ocm-transfer-pod -- mkdir -p "$pod_path"
    kubectl cp "$cache_dir" -n default "ocm-transfer-pod:$pod_path/"
    local component_name
    component_name=$(jq -r '.artifacts[0].repository // ""' "$cache_dir/artifact-index.json" 2>/dev/null | sed 's|^component-descriptors/||')
    kubectl exec -i ocm-transfer-pod -- ocm transfer component-version \
        "ctf::$pod_path/$(basename "$cache_dir")//$component_name:$ver" "$cluster_oci"

    # OCM v2 graph discovery requires all componentReferences and their transitive deps to be
    # present in the target CTF before 'add component-versions' runs. Transfer the full tree
    # (--recursive) from upstream into both the CTF (for discovery) and the local OCI registry
    # (for the OCM toolkit to follow componentReference chains at runtime).
    echo -e "${COL}[$(date '+%H:%M:%S')] $name: pre-populating CTF and local OCI with recursive transfer...${COL_RES}"
    kubectl exec -i ocm-transfer-pod -- ocm transfer component-version --recursive \
        "$ref:$ver" "ctf::.ocm/transport.ctf"
    kubectl exec -i ocm-transfer-pod -- ocm transfer component-version --recursive \
        "$ref:$ver" "$cluster_oci"
}

# Resolve all component versions
resolve_component_versions() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Resolving component versions...${COL_RES}"

    # Local/remote component versions
    get_component_version account-operator github.com/platform-mesh/account-operator charts/account-operator ACCOUNT_OPERATOR_VERSION
    get_component_version security-operator github.com/platform-mesh/security-operator charts/security-operator SECURITY_OPERATOR_VERSION
    get_component_version extension-manager-operator github.com/platform-mesh/extension-manager-operator charts/extension-manager-operator EXTENSION_MANAGER_OPERATOR_VERSION
    get_component_version infra github.com/platform-mesh/infra charts/infra INFRA_VERSION
    get_component_version rebac-authz-webhook github.com/platform-mesh/rebac-authz-webhook charts/rebac-authz-webhook REBAC_AUTHZ_WEBHOOK_VERSION
    get_component_version portal github.com/platform-mesh/portal charts/portal/ PORTAL_VERSION
    get_component_version platform-mesh-operator github.com/platform-mesh/platform-mesh-operator charts/platform-mesh-operator/ PLATFORM_MESH_OPERATOR_VERSION
    get_component_version kubernetes-graphql-gateway github.com/platform-mesh/kubernetes-graphql-gateway charts/kubernetes-graphql-gateway KUBERNETES_GRAPHQL_GATEWAY_VERSION
    get_component_version virtual-workspaces github.com/platform-mesh/virtual-workspaces charts/virtual-workspaces VIRTUAL_WORKSPACES_VERSION
    get_component_version keycloak-operator github.com/platform-mesh/keycloak-operator charts/keycloak-operator KEYCLOAK_OPERATOR_VERSION
    get_component_version iam-service github.com/platform-mesh/iam-service charts/iam-service IAM_SERVICE_VERSION
    get_component_version iam-ui github.com/platform-mesh/iam-ui charts/iam-ui IAM_UI_VERSION
    get_component_version marketplace-ui github.com/platform-mesh/marketplace-ui charts/marketplace-ui MARKETPLACE_UI_VERSION
    get_component_version example-httpbin-operator github.com/platform-mesh/example-httpbin-operator charts/example-httpbin-operator EXAMPLE_HTTPBIN_OPERATOR_VERSION
    get_component_version kro-composition-operator github.com/platform-mesh/kro-composition-operator charts/kro-composition-operator KRO_COMPOSITION_OPERATOR_VERSION
    get_component_version terminal-controller-manager github.com/platform-mesh/terminal-controller-manager charts/terminal-controller-manager TERMINAL_CONTROLLER_MANAGER_VERSION
    get_component_version observability github.com/platform-mesh/observability charts/observability OBSERVABILITY_VERSION

    echo -e "${COL}[$(date '+%H:%M:%S')] Resolving third-party component versions...${COL_RES}"

    # Third-party version pins live in .github/workflows/ocm-aggregator.yaml's env block.
    local agg="$PROJECT_ROOT/.github/workflows/ocm-aggregator.yaml"
    export KCP_OPERATOR_CHART_VERSION=$(yq -r '.jobs.ocm.env.KCP_OPERATOR_CHART_VERSION' "$agg")
    export KCP_OPERATOR_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.KCP_OPERATOR_IMAGE_VERSION' "$agg")
    export KCP_VERSION=$(yq -r '.jobs.ocm.env.KCP_VERSION' "$agg")
    export INIT_AGENT_CHART_VERSION=$(yq -r '.jobs.ocm.env.INIT_AGENT_CHART_VERSION' "$agg")
    export INIT_AGENT_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.INIT_AGENT_IMAGE_VERSION' "$agg")
    export API_SYNCAGENT_CHART_VERSION=$(yq -r '.jobs.ocm.env.API_SYNCAGENT_CHART_VERSION' "$agg")
    export API_SYNCAGENT_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.API_SYNCAGENT_IMAGE_VERSION' "$agg")
    export OPENFGA_VERSION=$(yq -r '.jobs.ocm.env.OPENFGA_VERSION' "$agg")
    export OPENFGA_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.OPENFGA_IMAGE_VERSION' "$agg")
    export OPENFGA_POSTGRESQL_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.OPENFGA_POSTGRESQL_IMAGE_VERSION' "$agg")
    export GATEWAY_API_VERSION=$(yq -r '.jobs.ocm.env.GATEWAY_API_VERSION' "$agg")
    export GATEWAY_API_COMMIT=$(yq -r '.jobs.ocm.env.GATEWAY_API_COMMIT' "$agg")
    export TRAEFIK_VERSION=$(yq -r '.jobs.ocm.env.TRAEFIK_VERSION' "$agg")
    export TRAEFIK_CHART_VERSION=$(yq -r '.jobs.ocm.env.TRAEFIK_CHART_VERSION' "$agg")
    export TRAEFIK_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.TRAEFIK_IMAGE_VERSION' "$agg")
    export TRAEFIK_CRD_VERSION=$(yq -r '.jobs.ocm.env.TRAEFIK_CRD_VERSION' "$agg")
    export CERT_MANAGER_VERSION=$(yq -r '.jobs.ocm.env.CERT_MANAGER_VERSION' "$agg")
    export CNPG_OPERATOR_CHART_VERSION=$(yq -r '.jobs.ocm.env.CNPG_OPERATOR_CHART_VERSION' "$agg")
    export CNPG_OPERATOR_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.CNPG_OPERATOR_IMAGE_VERSION' "$agg")
    export PROMETHEUS_OPERATOR_CRDS_VERSION=$(yq -r '.jobs.ocm.env.PROMETHEUS_OPERATOR_CRDS_VERSION' "$agg")
    export KUBE_PROMETHEUS_STACK_VERSION=$(yq -r '.jobs.ocm.env.KUBE_PROMETHEUS_STACK_VERSION' "$agg")
    export OPENTELEMETRY_OPERATOR_VERSION=$(yq -r '.jobs.ocm.env.OPENTELEMETRY_OPERATOR_VERSION' "$agg")
    export OTEL_OPERATOR_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.OTEL_OPERATOR_IMAGE_VERSION' "$agg")
    export OTEL_COLLECTOR_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.OTEL_COLLECTOR_IMAGE_VERSION' "$agg")
    export OTEL_TARGET_ALLOCATOR_VERSION=$(yq -r '.jobs.ocm.env.OTEL_TARGET_ALLOCATOR_VERSION' "$agg")
    export KEYCLOAK_VERSION=$(yq -r '.jobs.ocm.env.PM_KEYCLOAK_VERSION' "$agg")
    export GARDENER_ETCD_DRUID_VERSION=$(yq -r '.jobs.ocm.env.GARDENER_ETCD_DRUID_VERSION' "$agg")

    # PM-stamped component descriptor versions for third-party components.
    # Bump the suffix here to publish a new descriptor without touching resource versions.
    # Must match the values in .github/workflows/ocm-aggregator.yaml.
    export PM_GATEWAY_API_VERSION="0.0.1"
    export PM_TRAEFIK_VERSION="0.0.1"
    export PM_CERT_MANAGER_VERSION="0.0.1"
    export PM_KCP_OPERATOR_VERSION="0.0.1"
    export PM_KCP_VERSION="0.0.3"
    export PM_INIT_AGENT_VERSION="0.0.1"
    export PM_OPENFGA_VERSION="0.0.1"
    export PM_CNPG_OPERATOR_VERSION="0.0.1"
    export PM_PROMETHEUS_OPERATOR_CRDS_VERSION="0.0.1"
    export PM_KUBE_PROMETHEUS_STACK_VERSION="0.0.1"
    export PM_OPENTELEMETRY_OPERATOR_VERSION="0.0.2"

    transfer_from_cache etcd-druid \
        europe-docker.pkg.dev/gardener-project/releases//github.com/gardener/etcd-druid \
        "$GARDENER_ETCD_DRUID_VERSION"

    # gateway-api uses 'type: github' in its inline constructor definition which OCM v2 cannot
    # resolve locally. We strip the inline definition but keep the componentReference.
    # Transfer the pre-built component from ghcr.io/platform-mesh into both the CTF (for v2
    # graph discovery during add component-versions) and the local OCI registry (for toolkit runtime).
    echo -e "${COL}[$(date '+%H:%M:%S')] Transferring gateway-api from ghcr.io/platform-mesh to CTF and local OCI...${COL_RES}"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer component-version \
        "ghcr.io/platform-mesh//github.com/kubernetes-sigs/gateway-api:${PM_GATEWAY_API_VERSION}" \
        "ctf::.ocm/transport.ctf"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer component-version \
        "ghcr.io/platform-mesh//github.com/kubernetes-sigs/gateway-api:${PM_GATEWAY_API_VERSION}" \
        "$LOCAL_REGISTRY/platform-mesh"
    echo -e "${COL}[$(date '+%H:%M:%S')] gateway-api transferred${COL_RES}"

    # ingress-nginx is referenced by the example-httpbin-operator component-specific constructor.
    # Transfer from ghcr.io/platform-mesh into CTF (for v2 graph discovery) and local OCI (for toolkit).
    echo -e "${COL}[$(date '+%H:%M:%S')] Transferring ingress-nginx from ghcr.io/platform-mesh to CTF and local OCI...${COL_RES}"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer component-version \
        "ghcr.io/platform-mesh//github.com/kubernetes/ingress-nginx:4.11.3" \
        "ctf::.ocm/transport.ctf"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer component-version \
        "ghcr.io/platform-mesh//github.com/kubernetes/ingress-nginx:4.11.3" \
        "$LOCAL_REGISTRY/platform-mesh"
    echo -e "${COL}[$(date '+%H:%M:%S')] ingress-nginx transferred${COL_RES}"

    echo -e "${COL}[$(date '+%H:%M:%S')] Finished resolving component versions${COL_RES}"
}

# Build the final prerelease component
build_final_component() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Building final prerelease component...${COL_RES}"

    # Copy constructor to pod
    kubectl cp "$OCM_DIR/component-constructor-prerelease.yaml" -n default ocm-transfer-pod:.ocm/component-constructor-prerelease.yaml

    # Build the component
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- \
        env \
        VERSION="$COMPONENT_PRERELEASE_VERSION" \
        ISTIO_VERSION="$ISTIO_VERSION" \
        OPENFGA_VERSION="$OPENFGA_VERSION" \
        PM_OPENFGA_VERSION="$PM_OPENFGA_VERSION" \
        KCP_OPERATOR_VERSION="$KCP_OPERATOR_VERSION" \
        GARDENER_ETCD_DRUID_VERSION="$GARDENER_ETCD_DRUID_VERSION" \
        ACCOUNT_OPERATOR_VERSION="$ACCOUNT_OPERATOR_VERSION" \
        PLATFORM_MESH_OPERATOR_VERSION="$PLATFORM_MESH_OPERATOR_VERSION" \
        EXTENSION_MANAGER_OPERATOR_VERSION="$EXTENSION_MANAGER_OPERATOR_VERSION" \
        SECURITY_OPERATOR_VERSION="$SECURITY_OPERATOR_VERSION" \
        REBAC_AUTHZ_WEBHOOK_VERSION="$REBAC_AUTHZ_WEBHOOK_VERSION" \
        INFRA_VERSION="$INFRA_VERSION" \
        KUBERNETES_GRAPHQL_GATEWAY_VERSION="$KUBERNETES_GRAPHQL_GATEWAY_VERSION" \
        PORTAL_VERSION="$PORTAL_VERSION" \
        KEYCLOAK_VERSION="$KEYCLOAK_VERSION" \
        PM_KEYCLOAK_VERSION="$KEYCLOAK_VERSION" \
        KEYCLOAK_OPERATOR_VERSION="$KEYCLOAK_OPERATOR_VERSION" \
        VIRTUAL_WORKSPACES_VERSION="$VIRTUAL_WORKSPACES_VERSION" \
        EXAMPLE_HTTPBIN_OPERATOR_VERSION="$EXAMPLE_HTTPBIN_OPERATOR_VERSION" \
        KRO_COMPOSITION_OPERATOR_VERSION="$KRO_COMPOSITION_OPERATOR_VERSION" \
        IAM_SERVICE_VERSION="$IAM_SERVICE_VERSION" \
        IAM_UI_VERSION="$IAM_UI_VERSION" \
        MARKETPLACE_UI_VERSION="$MARKETPLACE_UI_VERSION" \
        GATEWAY_API_VERSION="$GATEWAY_API_VERSION" \
        GATEWAY_API_COMMIT="$GATEWAY_API_COMMIT" \
        TRAEFIK_VERSION="$TRAEFIK_VERSION" \
        TRAEFIK_CRD_VERSION="$TRAEFIK_CRD_VERSION" \
        TRAEFIK_CHART_VERSION="$TRAEFIK_CHART_VERSION" \
        CERT_MANAGER_VERSION="$CERT_MANAGER_VERSION" \
        KCP_OPERATOR_CHART_VERSION="$KCP_OPERATOR_CHART_VERSION" \
        KCP_OPERATOR_IMAGE_VERSION="$KCP_OPERATOR_IMAGE_VERSION" \
        KCP_VERSION="$KCP_VERSION" \
        INIT_AGENT_CHART_VERSION="$INIT_AGENT_CHART_VERSION" \
        INIT_AGENT_IMAGE_VERSION="$INIT_AGENT_IMAGE_VERSION" \
        API_SYNCAGENT_CHART_VERSION="$API_SYNCAGENT_CHART_VERSION" \
        API_SYNCAGENT_IMAGE_VERSION="$API_SYNCAGENT_IMAGE_VERSION" \
        TRAEFIK_IMAGE_VERSION="$TRAEFIK_IMAGE_VERSION" \
        OPENFGA_IMAGE_VERSION="$OPENFGA_IMAGE_VERSION" \
        OPENFGA_POSTGRESQL_IMAGE_VERSION="$OPENFGA_POSTGRESQL_IMAGE_VERSION" \
        CNPG_OPERATOR_VERSION="$CNPG_OPERATOR_VERSION" \
        CNPG_OPERATOR_CHART_VERSION="$CNPG_OPERATOR_CHART_VERSION" \
        CNPG_OPERATOR_IMAGE_VERSION="$CNPG_OPERATOR_IMAGE_VERSION" \
        TERMINAL_CONTROLLER_MANAGER_VERSION="$TERMINAL_CONTROLLER_MANAGER_VERSION" \
        OBSERVABILITY_VERSION="$OBSERVABILITY_VERSION" \
        PROMETHEUS_OPERATOR_CRDS_VERSION="$PROMETHEUS_OPERATOR_CRDS_VERSION" \
        KUBE_PROMETHEUS_STACK_VERSION="$KUBE_PROMETHEUS_STACK_VERSION" \
        OPENTELEMETRY_OPERATOR_VERSION="$OPENTELEMETRY_OPERATOR_VERSION" \
        OTEL_OPERATOR_IMAGE_VERSION="$OTEL_OPERATOR_IMAGE_VERSION" \
        OTEL_COLLECTOR_IMAGE_VERSION="$OTEL_COLLECTOR_IMAGE_VERSION" \
        OTEL_TARGET_ALLOCATOR_VERSION="$OTEL_TARGET_ALLOCATOR_VERSION" \
        PM_GATEWAY_API_VERSION="$PM_GATEWAY_API_VERSION" \
        PM_TRAEFIK_VERSION="$PM_TRAEFIK_VERSION" \
        PM_CERT_MANAGER_VERSION="$PM_CERT_MANAGER_VERSION" \
        PM_KCP_OPERATOR_VERSION="$PM_KCP_OPERATOR_VERSION" \
        PM_KCP_VERSION="$PM_KCP_VERSION" \
        PM_INIT_AGENT_VERSION="$PM_INIT_AGENT_VERSION" \
        PM_CNPG_OPERATOR_VERSION="$PM_CNPG_OPERATOR_VERSION" \
        PM_PROMETHEUS_OPERATOR_CRDS_VERSION="$PM_PROMETHEUS_OPERATOR_CRDS_VERSION" \
        PM_KUBE_PROMETHEUS_STACK_VERSION="$PM_KUBE_PROMETHEUS_STACK_VERSION" \
        PM_OPENTELEMETRY_OPERATOR_VERSION="$PM_OPENTELEMETRY_OPERATOR_VERSION" \
        ocm add component-versions \
        --component-version-conflict-policy replace \
        --repository "ctf::.ocm/transport.ctf" \
        --constructor .ocm/component-constructor-prerelease.yaml

    echo ""
    echo -e "${COL}[$(date '+%H:%M:%S')] Built prerelease component version $COMPONENT_PRERELEASE_VERSION (local overrides: $CUSTOM_LOCAL_COMPONENTS)${COL_RES}"

    # Transfer the prerelease component to the local OCI registry
    echo -e "${COL}[$(date '+%H:%M:%S')] Transferring prerelease component to local OCI registry...${COL_RES}"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- \
        ocm transfer component-version \
        "ctf::.ocm/transport.ctf//github.com/platform-mesh/prerelease:$COMPONENT_PRERELEASE_VERSION" \
        "$LOCAL_REGISTRY/platform-mesh"

    # Transfer all inline third-party components (traefik, cert-manager, kcp, etc.) to the local OCI registry.
    # These are built as part of the prerelease constructor and must be resolvable by the OCM toolkit.
    echo -e "${COL}[$(date '+%H:%M:%S')] Transferring inline third-party components to local OCI registry...${COL_RES}"
    local _transfer_third_party
    _transfer_third_party() {
        local ref="$1"
        kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- \
            ocm get component-version "ctf::.ocm/transport.ctf//$ref" >/dev/null 2>&1 || return 0
        kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- \
            ocm transfer component-version "ctf::.ocm/transport.ctf//$ref" "$LOCAL_REGISTRY/platform-mesh" \
            || echo -e "${RED}Warning: failed to transfer $ref${COL_RES}"
    }
    _transfer_third_party "github.com/traefik/traefik:${PM_TRAEFIK_VERSION}"
    _transfer_third_party "github.com/cert-manager/cert-manager:${PM_CERT_MANAGER_VERSION}"
    _transfer_third_party "github.com/openfga/openfga:${PM_OPENFGA_VERSION}"
    _transfer_third_party "github.com/kcp-dev/kcp-operator:${PM_KCP_OPERATOR_VERSION}"
    _transfer_third_party "github.com/kcp-dev/kcp:${PM_KCP_VERSION}"
    _transfer_third_party "github.com/kcp-dev/init-agent:${PM_INIT_AGENT_VERSION}"
    _transfer_third_party "github.com/kcp-dev/api-syncagent:${API_SYNCAGENT_CHART_VERSION}"
    _transfer_third_party "github.com/cloudnative-pg/cloudnative-pg:${PM_CNPG_OPERATOR_VERSION}"
    _transfer_third_party "github.com/prometheus-community/prometheus-operator-crds:${PM_PROMETHEUS_OPERATOR_CRDS_VERSION}"
    _transfer_third_party "github.com/prometheus-community/kube-prometheus-stack:${PM_KUBE_PROMETHEUS_STACK_VERSION}"
    _transfer_third_party "github.com/open-telemetry/opentelemetry-operator:${PM_OPENTELEMETRY_OPERATOR_VERSION}"
    echo -e "${COL}[$(date '+%H:%M:%S')] Prerelease component transferred successfully${COL_RES}"
}

# Main build function
build_component() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Starting OCM component build...${COL_RES}"

    # Ensure kubeconfig is set
    kind export kubeconfig -n platform-mesh

    # Setup OCM CLI
    setup_ocm_cli
    export_ocm_path

    # Update constructor template
    update_constructor

    # Build local charts (this also sets up the transport archive)
    build_local_charts

    # Resolve component versions
    resolve_component_versions

    # Build final component
    build_final_component

    # Transfer to local OCI registry
    transfer_to_local_oci

    echo -e "${COL}[$(date '+%H:%M:%S')] OCM component build completed successfully${COL_RES}"
}

# Main function
main() {
    build_component
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
