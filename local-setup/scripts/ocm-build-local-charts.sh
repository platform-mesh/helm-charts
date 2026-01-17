#!/bin/bash

# OCM Build Local Charts Script
# Builds local helm charts and pushes them to the local OCI registry

set -e

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source OCM setup
source "$SCRIPT_DIR/ocm-setup.sh"

# Configuration
LOCAL_BIN="${LOCAL_BIN:-$PROJECT_ROOT/bin}"
OCM_DIR="${OCM_DIR:-$PROJECT_ROOT/.ocm}"
PRERELEASE_DIR="${PRERELEASE_DIR:-$PROJECT_ROOT/prerelease}"

# Local charts to build (component-name:chart-path)
CUSTOM_LOCAL_COMPONENTS_CHART_PATHS=(
    "account-operator:charts/account-operator"
    "example-httpbin-operator:charts/example-httpbin-operator"
    "extension-manager-operator:charts/extension-manager-operator"
    "iam-service:charts/iam-service"
    "iam-ui:charts/iam-ui"
    "infra:charts/infra"
    "kubernetes-graphql-gateway:charts/kubernetes-graphql-gateway"
    "organization-idp:charts/organization-idp"
    "platform-mesh-operator:charts/platform-mesh-operator"
    "platform-mesh-operator-components:charts/platform-mesh-operator-components"
    "platform-mesh-operator-infra-components:charts/platform-mesh-operator-infra-components"
    "portal:charts/portal"
    "rebac-authz-webhook:charts/rebac-authz-webhook"
    "security-operator:charts/security-operator"
    "virtual-workspaces:charts/virtual-workspaces"
)

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

# Determine kubectl exec flags based on TTY availability
# -t allocates a pseudo-TTY, -i keeps stdin open
# Some environments (CI, non-interactive shells) don't have TTY
KUBECTL_EXEC_FLAGS="-i"
if [ -t 0 ]; then
    KUBECTL_EXEC_FLAGS="-ti"
fi

# Copy constructor templates to transfer pod
copy_templates_to_pod() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Copying OCM constructor templates to transfer pod...${COL_RES}"
    kubectl cp "$OCM_DIR/component-constructor.yaml" -n default ocm-transfer-pod:.ocm/component-constructor.yaml
    kubectl cp "$OCM_DIR/component-constructor-chart-only.yaml" -n default ocm-transfer-pod:.ocm/component-constructor-chart-only.yaml
}

# Build and push a single chart to local OCI registry
build_and_push_chart() {
    local comp="$1"
    local chart_dir="$2"

    echo -e "${COL}[$(date '+%H:%M:%S')] Processing $chart_dir${COL_RES}"

    # Get component name from prerelease constructor
    local component_name
    component_name=$(yq -r ".components[] | select(.name == \"github.com/platform-mesh/prerelease\") | .componentReferences[] | select(.name == \"$comp\") | .componentName" "$OCM_DIR/component-constructor-prerelease.yaml" 2>/dev/null || true)

    if [ -z "$component_name" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Skipping $comp - not found in component-constructor-prerelease.yaml${COL_RES}"
        return 0
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] Component: $component_name (chart dir: $chart_dir)${COL_RES}"

    # Get chart version and app version
    local chart_version app_version
    chart_version=$(grep '^version:' "$PROJECT_ROOT/$chart_dir/Chart.yaml" | sed 's/^version: //')
    if [ -z "$chart_version" ]; then
        echo -e "${RED}Failed to read version for $component_name${COL_RES}" >&2
        exit 1
    fi
    app_version=$(yq -r '.appVersion // ""' "$PROJECT_ROOT/$chart_dir/Chart.yaml" 2>/dev/null || true)

    # Package the chart
    local out tarball
    out=$(helm package "$PROJECT_ROOT/$chart_dir" -d "$PRERELEASE_DIR")
    tarball=$(echo "$out" | awk -F': ' '/saved it to:/ {print $2}')

    if [ ! -f "$tarball" ]; then
        echo -e "${RED}Failed to package $component_name${COL_RES}" >&2
        exit 1
    fi

    # Push to local OCI registry
    echo -e "${COL}[$(date '+%H:%M:%S')] Pushing $tarball to local OCI registry...${COL_RES}"
    kubectl cp "$tarball" -n default ocm-transfer-pod:.
    kubectl exec $KUBECTL_EXEC_FLAGS ocm-transfer-pod -- helm push "$(basename "$tarball")" oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh
    echo -e "${COL}[$(date '+%H:%M:%S')] Pushed $tarball to local OCI registry${COL_RES}"

    # Get image name and prepare variables
    local image_name commit chart_real_name chart_oci_path
    image_name=$(yq '.image["name"] // ""' "$PROJECT_ROOT/$chart_dir/values.yaml")
    commit=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    chart_real_name=$(grep '^name:' "$PROJECT_ROOT/$chart_dir/Chart.yaml" | awk '{print $2}')
    chart_oci_path="oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh/$comp"
    local_chart_path="../$chart_dir"

    echo ""
    echo "VERSION=$chart_version"
    echo "APP_VERSION=$app_version"
    echo "IMAGE_NAME=$image_name"
    echo "COMMIT=$commit"
    echo "COMPONENT_NAME=$component_name"
    echo "CHART_OCI_PATH=$chart_oci_path"
    echo "LOCAL_CHART_PATH=$local_chart_path"
    echo ""

    # Add component to OCM transport archive
    echo -e "${COL}[$(date '+%H:%M:%S')] Adding component: $component_name version $chart_version${COL_RES}"

    if [ "$app_version" == "0.0.0" ] || [ -z "$image_name" ]; then
        echo "Using ocm-constructor-file: .ocm/component-constructor-chart-only.yaml (APP_VERSION=$app_version, IMAGE_NAME=$image_name)"
        kubectl exec $KUBECTL_EXEC_FLAGS ocm-transfer-pod -- ocm add components -c --templater=go --file ".ocm/transport.ctf" .ocm/component-constructor-chart-only.yaml -- \
            VERSION="$chart_version" \
            APP_VERSION="$app_version" \
            IMAGE_NAME="$image_name" \
            COMMIT="$commit" \
            IMAGE_REPO_SHA="$commit" \
            CHART_REPO="$component_name" \
            COMPONENT_NAME="$component_name" \
            CHART_OCI_PATH="$chart_oci_path" \
            LOCAL_CHART_PATH="$local_chart_path"
    else
        kubectl exec $KUBECTL_EXEC_FLAGS ocm-transfer-pod -- ocm add components -c --templater=go --file ".ocm/transport.ctf" .ocm/component-constructor.yaml -- \
            VERSION="$chart_version" \
            APP_VERSION="$app_version" \
            IMAGE_NAME="$image_name" \
            IMAGE_REPO="$component_name" \
            COMMIT="$commit" \
            IMAGE_REPO_SHA="$commit" \
            CHART_REPO="$component_name" \
            COMPONENT_NAME="$component_name" \
            CHART_OCI_PATH="$chart_oci_path" \
            LOCAL_CHART_PATH="$local_chart_path"
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] Done: $component_name${COL_RES}"
    echo
}

# Transfer OCM transport archive to local OCI registry
transfer_to_local_oci() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Transferring OCM transport archive to local OCI registry...${COL_RES}"
    kubectl exec $KUBECTL_EXEC_FLAGS ocm-transfer-pod -- ocm transfer ctf --overwrite .ocm/transport.ctf oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh || true
}

# Build all local charts
build_local_charts() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Building custom local charts...${COL_RES}"

    # Ensure kubeconfig is set
    kind export kubeconfig -n platform-mesh

    # Create prerelease directory
    mkdir -p "$PRERELEASE_DIR"
    rm -f "$PRERELEASE_DIR"/*.tgz

    # Setup OCM CLI
    setup_ocm_cli
    export_ocm_path

    # Copy templates to pod
    copy_templates_to_pod

    # Build each chart
    for pair in "${CUSTOM_LOCAL_COMPONENTS_CHART_PATHS[@]}"; do
        local comp="${pair%%:*}"
        local chart_dir="${pair#*:}"
        build_and_push_chart "$comp" "$chart_dir"
    done

    # Transfer to local OCI registry
    transfer_to_local_oci

    echo -e "${COL}[$(date '+%H:%M:%S')] Completed building custom local charts${COL_RES}"
}

# Main function
main() {
    build_local_charts
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
