#!/bin/bash

# OCM Build Component Script
# Main entry point for building the complete OCM prerelease component
# This script replaces the functionality of `task ocm:build`

set -e

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
CUSTOM_LOCAL_COMPONENTS="account-operator,example-httpbin-operator,extension-manager-operator,iam-service,iam-ui,infra,kubernetes-graphql-gateway,platform-mesh-operator,platform-mesh-operator-components,platform-mesh-operator-infra-components,portal,rebac-authz-webhook,security-operator,virtual-workspaces"

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
    echo -e "${COL}[$(date '+%H:%M:%S')] Downloading component-constructor-prerelease.yaml...${COL_RES}"

    curl -o "$OCM_DIR/component-constructor-prerelease.yaml" \
        https://raw.githubusercontent.com/platform-mesh/ocm/refs/heads/main/constructor/component-constructor.yaml

    # Rename the component from platform-mesh to prerelease
    sed 's/name:\ github.com\/platform-mesh\/platform-mesh/name:\ github.com\/platform-mesh\/prerelease/' \
        "$OCM_DIR/component-constructor-prerelease.yaml" > "$OCM_DIR/component-constructor-prerelease.yaml.tmp" \
        && mv "$OCM_DIR/component-constructor-prerelease.yaml.tmp" "$OCM_DIR/component-constructor-prerelease.yaml"

    echo -e "${COL}[$(date '+%H:%M:%S')] Component constructor updated${COL_RES}"
}

# Check if a component is local
is_local() {
    echo ",$CUSTOM_LOCAL_COMPONENTS," | grep -q ",$1,"
}

# Get component version (local or remote)
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
            kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer componentversion --copy-resources --no-update ghcr.io/platform-mesh//$component:$ver https://$LOCAL_REGISTRY/platform-mesh
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

    # 3. Get from remote registry
    local repo="ghcr.io/platform-mesh"
    local val
    val=$(kubectl exec ocm-transfer-pod -- ocm get componentversions --latest "$component" --repo "$repo" -o json 2>/dev/null | jq -r '.items[0].component.version' 2>/dev/null || true)

    if [ -z "$val" ] || [ "$val" = "null" ]; then
        repo="ghcr.io/platform-mesh/images"
        echo "Primary repo lookup failed for $component, trying fallback repo $repo"
        val=$(kubectl exec ocm-transfer-pod -- ocm get componentversions --latest "$component" --repo "$repo" -o json 2>/dev/null | jq -r '.items[0].component.version' 2>/dev/null || true)
    fi

    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo -e "${RED}Failed to resolve remote version for $component${COL_RES}" >&2
        exit 1
    fi

    echo "Using REMOTE component version for $short -> $val"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer componentversion --copy-resources --overwrite "$repo//$component:$val" .ocm/transport.ctf
    export "$env_var"="$val"
}

# Get resource version from OCM
get_ocm_resource_version() {
    local component="$1"
    local query="$2"
    "$LOCAL_BIN/ocm" --config "$OCM_DIR/config" get resources "oci://ghcr.io/platform-mesh//$component" --latest -o json | jq -r "$query"
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
    get_component_version portal github.com/platform-mesh/portal "../helm-charts/charts/portal/" PORTAL_VERSION
    get_component_version platform-mesh-operator github.com/platform-mesh/platform-mesh-operator charts/platform-mesh-operator/ PLATFORM_MESH_OPERATOR_VERSION
    get_component_version kubernetes-graphql-gateway github.com/platform-mesh/kubernetes-graphql-gateway charts/kubernetes-graphql-gateway KUBERNETES_GRAPHQL_GATEWAY_VERSION
    get_component_version virtual-workspaces github.com/platform-mesh/virtual-workspaces charts/virtual-workspaces VIRTUAL_WORKSPACES_VERSION
    get_component_version keycloak github.com/platform-mesh/keycloak "../helm-charts/keycloak/" KEYCLOAK_VERSION
    get_component_version platform-mesh-operator-components github.com/platform-mesh/platform-mesh-operator-components charts/platform-mesh-operator-components PLATFORM_MESH_OPERATOR_COMPONENTS_VERSION
    get_component_version platform-mesh-operator-infra-components github.com/platform-mesh/platform-mesh-operator-infra-components charts/platform-mesh-operator-infra-components PLATFORM_MESH_OPERATOR_INFRA_COMPONENTS_VERSION
    get_component_version iam-service github.com/platform-mesh/iam-service charts/iam-service IAM_SERVICE_VERSION
    get_component_version iam-ui github.com/platform-mesh/iam-ui charts/iam-ui IAM_UI_VERSION
    get_component_version marketplace-ui github.com/platform-mesh/marketplace-ui charts/marketplace-ui MARKETPLACE_UI_VERSION
    get_component_version organization-idp github.com/platform-mesh/organization-idp "" ORGANIZATION_IDP_VERSION
    get_component_version example-httpbin-operator github.com/platform-mesh/example-httpbin-operator charts/example-httpbin-operator EXAMPLE_HTTPBIN_OPERATOR_VERSION

    echo -e "${COL}[$(date '+%H:%M:%S')] Resolving third-party component versions...${COL_RES}"

    # Third-party components (always remote)
    export CROSSPLANE_VERSION=$(get_ocm_resource_version "github.com/crossplane/crossplane" '.items[0].element["version"]')
    export ISTIO_VERSION=$(get_ocm_resource_version "github.com/istio/istio/base" '.items[0].element["version"]')
    export OPENFGA_VERSION=$(get_ocm_resource_version "github.com/openfga/openfga" '.items[0].element["version"]')
    export KCP_OPERATOR_VERSION=$(get_ocm_resource_version "github.com/kcp-dev/kcp-operator" '.items[0].element["version"]')
    export KCP_IMAGE_VERSION=$(get_ocm_resource_version "github.com/kcp-dev/kcp-operator" '.items[] | select(.element.type == "ociImage") | .element.version' | sed 's/^0\.0\.0-//')
    export GARDENER_ETCD_DRUID_SOURCE_REF=$(get_ocm_resource_version "github.com/gardener/etcd-druid" '.items[] | select(.element.type == "ociImage" and .element.name == "image") | .element.version')
    export GARDENER_ETCD_DRUID_CHART_VERSION=$(get_ocm_resource_version "github.com/gardener/etcd-druid" '.items[] | select(.element.type == "helmChart") | .element.version')
    export GATEWAY_API_VERSION=$(get_ocm_resource_version "github.com/kubernetes-sigs/gateway-api" '.items[0].element["version"]')
    export GATEWAY_API_COMMIT=$(get_ocm_resource_version "github.com/kubernetes-sigs/gateway-api" '.items[0].element.access["commit"]')
    export TRAEFIK_VERSION=$(get_ocm_resource_version "github.com/traefik/traefik" '.items[0].element["version"]')
    export TRAEFIK_CRD_VERSION=$(get_ocm_resource_version "github.com/traefik/traefik" '.items[1].element["version"]')
    export CERT_MANAGER_VERSION=$(get_ocm_resource_version "github.com/cert-manager/cert-manager" '.items[0].element["version"]')
    export KCP_OPERATOR_CHART_VERSION=$(get_ocm_resource_version "github.com/kcp-dev/kcp-operator" '.items[0].element["version"]')
    export KCP_OPERATOR_IMAGE_VERSION=$(get_ocm_resource_version "github.com/kcp-dev/kcp-operator" '.items[] | select(.element.type == "ociImage") | .element.version')
    export KCP_VERSION=$(get_ocm_resource_version "github.com/kcp-dev/kcp" '.items[0].element["version"]')
    export TRAEFIK_IMAGE_VERSION=$(get_ocm_resource_version "github.com/traefik/traefik" '.items[] | select(.element.type == "ociImage" and .element.name == "image") | .element.version')
    export CROSSPLANE_IMAGE_VERSION=$(get_ocm_resource_version "github.com/crossplane/crossplane" '.items[] | select(.element.type == "ociImage" and .element.name == "image") | .element.version')
    export CROSSPLANE_KEYCLOAK_PROVIDER_IMAGE_VERSION=$(get_ocm_resource_version "github.com/crossplane/crossplane" '.items[] | select(.element.type == "ociImage" and .element.name == "keycloak-provider") | .element.version')
    export OPENFGA_IMAGE_VERSION=$(get_ocm_resource_version "github.com/openfga/openfga" '.items[] | select(.element.type == "ociImage" and .element.name == "image") | .element.version')
    export GARDENER_ETCD_DRUID_ETCD_WRAPPER_IMAGE_VERSION=$(get_ocm_resource_version "github.com/gardener/etcd-druid" '.items[] | select(.element.type == "ociImage" and .element.name == "etcd-wrapper-image") | .element.version')
    export GARDENER_ETCD_DRUID_ETCD_BRCTL_IMAGE_VERSION=$(get_ocm_resource_version "github.com/gardener/etcd-druid" '.items[] | select(.element.type == "ociImage" and .element.name == "etcdbrctl-image") | .element.version')
    export OPENFGA_POSTGRESQL_IMAGE_VERSION=$(get_ocm_resource_version "github.com/openfga/openfga" '.items[] | select(.element.type == "ociImage" and .element.name == "postgresql-image") | .element.version')

    echo -e "${COL}[$(date '+%H:%M:%S')] Finished resolving component versions${COL_RES}"
}

# Build the final prerelease component
build_final_component() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Building final prerelease component...${COL_RES}"

    # Copy constructor to pod
    kubectl cp "$OCM_DIR/component-constructor-prerelease.yaml" -n default ocm-transfer-pod:.ocm/component-constructor-prerelease.yaml

    # Build the component
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm add components \
        --lookup "$LOCAL_REGISTRY" \
        -c --templater=go \
        --file ".ocm/transport.ctf" \
        .ocm/component-constructor-prerelease.yaml -- \
        VERSION="$COMPONENT_PRERELEASE_VERSION" \
        ISTIO_VERSION="$ISTIO_VERSION" \
        CROSSPLANE_VERSION="$CROSSPLANE_VERSION" \
        OPENFGA_VERSION="$OPENFGA_VERSION" \
        KCP_OPERATOR_VERSION="$KCP_OPERATOR_VERSION" \
        KCP_IMAGE_VERSION="$KCP_IMAGE_VERSION" \
        GARDENER_ETCD_DRUID_SOURCE_REF="$GARDENER_ETCD_DRUID_SOURCE_REF" \
        GARDENER_ETCD_DRUID_CHART_VERSION="$GARDENER_ETCD_DRUID_CHART_VERSION" \
        ACCOUNT_OPERATOR_VERSION="$ACCOUNT_OPERATOR_VERSION" \
        PLATFORM_MESH_OPERATOR_VERSION="$PLATFORM_MESH_OPERATOR_VERSION" \
        EXTENSION_MANAGER_OPERATOR_VERSION="$EXTENSION_MANAGER_OPERATOR_VERSION" \
        SECURITY_OPERATOR_VERSION="$SECURITY_OPERATOR_VERSION" \
        REBAC_AUTHZ_WEBHOOK_VERSION="$REBAC_AUTHZ_WEBHOOK_VERSION" \
        INFRA_VERSION="$INFRA_VERSION" \
        KUBERNETES_GRAPHQL_GATEWAY_VERSION="$KUBERNETES_GRAPHQL_GATEWAY_VERSION" \
        PORTAL_VERSION="$PORTAL_VERSION" \
        KEYCLOAK_VERSION="$KEYCLOAK_VERSION" \
        VIRTUAL_WORKSPACES_VERSION="$VIRTUAL_WORKSPACES_VERSION" \
        PLATFORM_MESH_OPERATOR_COMPONENTS_VERSION="$PLATFORM_MESH_OPERATOR_COMPONENTS_VERSION" \
        EXAMPLE_HTTPBIN_OPERATOR_VERSION="$EXAMPLE_HTTPBIN_OPERATOR_VERSION" \
        IAM_SERVICE_VERSION="$IAM_SERVICE_VERSION" \
        IAM_UI_VERSION="$IAM_UI_VERSION" \
        MARKETPLACE_UI_VERSION="$MARKETPLACE_UI_VERSION" \
        ORGANIZATION_IDP_VERSION="$ORGANIZATION_IDP_VERSION" \
        GATEWAY_API_VERSION="$GATEWAY_API_VERSION" \
        GATEWAY_API_COMMIT="$GATEWAY_API_COMMIT" \
        TRAEFIK_VERSION="$TRAEFIK_VERSION" \
        TRAEFIK_CRD_VERSION="$TRAEFIK_CRD_VERSION" \
        CERT_MANAGER_VERSION="$CERT_MANAGER_VERSION" \
        PLATFORM_MESH_OPERATOR_INFRA_COMPONENTS_VERSION="$PLATFORM_MESH_OPERATOR_INFRA_COMPONENTS_VERSION" \
        KCP_OPERATOR_CHART_VERSION="$KCP_OPERATOR_CHART_VERSION" \
        KCP_OPERATOR_IMAGE_VERSION="$KCP_OPERATOR_IMAGE_VERSION" \
        KCP_VERSION="$KCP_VERSION" \
        TRAEFIK_IMAGE_VERSION="$TRAEFIK_IMAGE_VERSION" \
        CROSSPLANE_IMAGE_VERSION="$CROSSPLANE_IMAGE_VERSION" \
        CROSSPLANE_KEYCLOAK_PROVIDER_IMAGE_VERSION="$CROSSPLANE_KEYCLOAK_PROVIDER_IMAGE_VERSION" \
        OPENFGA_IMAGE_VERSION="$OPENFGA_IMAGE_VERSION" \
        OPENFGA_POSTGRESQL_IMAGE_VERSION="$OPENFGA_POSTGRESQL_IMAGE_VERSION" \
        GARDENER_ETCD_DRUID_ETCD_WRAPPER_IMAGE_VERSION="$GARDENER_ETCD_DRUID_ETCD_WRAPPER_IMAGE_VERSION" \
        GARDENER_ETCD_DRUID_ETCD_BRCTL_IMAGE_VERSION="$GARDENER_ETCD_DRUID_ETCD_BRCTL_IMAGE_VERSION"

    echo ""
    echo -e "${COL}[$(date '+%H:%M:%S')] Built prerelease component version $COMPONENT_PRERELEASE_VERSION (local overrides: $CUSTOM_LOCAL_COMPONENTS)${COL_RES}"
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
