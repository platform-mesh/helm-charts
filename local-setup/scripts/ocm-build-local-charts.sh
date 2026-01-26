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

# Get kubectl exec flags based on current TTY availability
# Must be called at point of use, not script init, because background jobs lose TTY
# -t allocates a pseudo-TTY, -i keeps stdin open
get_kubectl_exec_flags() {
    if [ -t 0 ]; then
        echo "-ti"
    else
        echo "-i"
    fi
}

# Swap OCI common chart reference to local file reference (only for 'common' dependency)
# Operates on a copied chart in the prerelease directory to avoid modifying original files
swap_common_to_local() {
    local chart_path="$1"  # Full path to the copied chart
    local chart_yaml="$chart_path/Chart.yaml"

    # Check if this chart has a common dependency with OCI reference
    if grep -A2 "name: common" "$chart_yaml" | grep -q "oci://ghcr.io/platform-mesh/helm-charts"; then
        # Replace only the common chart's OCI reference with local file reference
        # Uses awk to only modify the repository line that follows "name: common"
        # Path is relative to the copied chart in prerelease/<comp>/, pointing to prerelease/common
        local temp_file
        temp_file=$(mktemp)
        awk '
            /- name: common/ { in_common=1 }
            in_common && /repository:.*oci:\/\/ghcr.io\/platform-mesh\/helm-charts/ {
                sub(/oci:\/\/ghcr.io\/platform-mesh\/helm-charts/, "file://../common")
                in_common=0
            }
            { print }
        ' "$chart_yaml" > "$temp_file"
        mv "$temp_file" "$chart_yaml"

        # Update dependencies to fetch local common chart
        helm dependency update "$chart_path" 2>/dev/null || true

        return 0  # swapped
    fi
    return 1  # no swap needed
}

# Copy constructor templates to transfer pod
copy_templates_to_pod() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Copying OCM constructor templates to transfer pod...${COL_RES}"
    kubectl cp "$OCM_DIR/component-constructor.yaml" -n default ocm-transfer-pod:.ocm/component-constructor.yaml
    kubectl cp "$OCM_DIR/component-constructor-chart-only.yaml" -n default ocm-transfer-pod:.ocm/component-constructor-chart-only.yaml
}

# Configuration for parallel execution
MAX_PARALLEL=${MAX_PARALLEL:-8}
SEQUENTIAL=${SEQUENTIAL:-false}

# Phase 1: Prepare chart and push to OCI registry (can run in parallel)
# This function handles steps 1-5: copy, swap, package, push to OCI
# Writes metadata to a temp file for phase 2
prepare_and_push_chart() {
    local comp="$1"
    local chart_dir="$2"
    local meta_file="$PRERELEASE_DIR/$comp.meta"

    echo -e "${COL}[$(date '+%H:%M:%S')] [Phase 1] Processing $chart_dir${COL_RES}"

    # Get component name from prerelease constructor
    local component_name
    component_name=$(yq -r ".components[] | select(.name == \"github.com/platform-mesh/prerelease\") | .componentReferences[] | select(.name == \"$comp\") | .componentName" "$OCM_DIR/component-constructor-prerelease.yaml" 2>/dev/null || true)

    if [ -z "$component_name" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Skipping $comp - not found in component-constructor-prerelease.yaml${COL_RES}"
        # Write skip marker
        echo "SKIP=true" > "$meta_file"
        return 0
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] Component: $component_name (chart dir: $chart_dir)${COL_RES}"

    # Get chart version and app version from original chart
    local chart_version app_version
    chart_version=$(grep '^version:' "$PROJECT_ROOT/$chart_dir/Chart.yaml" | sed 's/^version: //')
    if [ -z "$chart_version" ]; then
        echo -e "${RED}Failed to read version for $component_name${COL_RES}" >&2
        return 1
    fi
    app_version=$(yq -r '.appVersion // ""' "$PROJECT_ROOT/$chart_dir/Chart.yaml" 2>/dev/null || true)

    # Copy chart to prerelease directory to avoid modifying the original
    local prerelease_chart_dir="$PRERELEASE_DIR/$comp"
    rm -rf "$prerelease_chart_dir"
    cp -r "$PROJECT_ROOT/$chart_dir" "$prerelease_chart_dir"

    # Swap common chart reference to local in the copied chart (if it has the dependency)
    swap_common_to_local "$prerelease_chart_dir" || true

    # Package the chart from the prerelease copy
    local out tarball
    out=$(helm package "$prerelease_chart_dir" -d "$PRERELEASE_DIR")
    tarball=$(echo "$out" | awk -F': ' '/saved it to:/ {print $2}')

    if [ ! -f "$tarball" ]; then
        echo -e "${RED}Failed to package $component_name${COL_RES}" >&2
        return 1
    fi

    # Push to local OCI registry
    echo -e "${COL}[$(date '+%H:%M:%S')] Pushing $tarball to local OCI registry...${COL_RES}"
    kubectl cp "$tarball" -n default ocm-transfer-pod:.
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- helm push "$(basename "$tarball")" oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh
    echo -e "${COL}[$(date '+%H:%M:%S')] Pushed $tarball to local OCI registry${COL_RES}"

    # Get image name and prepare variables
    local image_name commit chart_oci_path local_chart_path
    image_name=$(yq '.image["name"] // ""' "$PROJECT_ROOT/$chart_dir/values.yaml")
    commit=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    chart_oci_path="oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh/$comp"
    local_chart_path="../$chart_dir"

    # Write metadata to file for phase 2
    cat > "$meta_file" << EOF
SKIP=false
VERSION=$chart_version
APP_VERSION=$app_version
IMAGE_NAME=$image_name
COMMIT=$commit
COMPONENT_NAME=$component_name
CHART_OCI_PATH=$chart_oci_path
LOCAL_CHART_PATH=$local_chart_path
EOF

    echo -e "${COL}[$(date '+%H:%M:%S')] [Phase 1] Done preparing: $comp${COL_RES}"
}

# Phase 2: Add chart to OCM CTF (must run sequentially)
# Reads metadata from temp file written by phase 1
add_chart_to_ctf() {
    local comp="$1"
    local meta_file="$PRERELEASE_DIR/$comp.meta"

    # Check if metadata file exists
    if [ ! -f "$meta_file" ]; then
        echo -e "${RED}[Phase 2] Metadata file not found for $comp${COL_RES}" >&2
        return 1
    fi

    # Source metadata
    source "$meta_file"

    # Check if this component should be skipped
    if [ "$SKIP" = "true" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] [Phase 2] Skipping $comp${COL_RES}"
        return 0
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] [Phase 2] Adding component: $COMPONENT_NAME version $VERSION${COL_RES}"

    # Add component to OCM transport archive
    if [ "$APP_VERSION" == "0.0.0" ] || [ -z "$IMAGE_NAME" ]; then
        kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm add components -c --templater=go --file ".ocm/transport.ctf" .ocm/component-constructor-chart-only.yaml -- \
            VERSION="$VERSION" \
            APP_VERSION="$APP_VERSION" \
            IMAGE_NAME="$IMAGE_NAME" \
            COMMIT="$COMMIT" \
            IMAGE_REPO_SHA="$COMMIT" \
            CHART_REPO="$COMPONENT_NAME" \
            COMPONENT_NAME="$COMPONENT_NAME" \
            CHART_OCI_PATH="$CHART_OCI_PATH" \
            LOCAL_CHART_PATH="$LOCAL_CHART_PATH"
    else
        kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm add components -c --templater=go --file ".ocm/transport.ctf" .ocm/component-constructor.yaml -- \
            VERSION="$VERSION" \
            APP_VERSION="$APP_VERSION" \
            IMAGE_NAME="$IMAGE_NAME" \
            IMAGE_REPO="$COMPONENT_NAME" \
            COMMIT="$COMMIT" \
            IMAGE_REPO_SHA="$COMMIT" \
            CHART_REPO="$COMPONENT_NAME" \
            COMPONENT_NAME="$COMPONENT_NAME" \
            CHART_OCI_PATH="$CHART_OCI_PATH" \
            LOCAL_CHART_PATH="$LOCAL_CHART_PATH"
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] [Phase 2] Done: $COMPONENT_NAME${COL_RES}"
}

# Transfer OCM transport archive to local OCI registry
transfer_to_local_oci() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Transferring OCM transport archive to local OCI registry...${COL_RES}"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer ctf --overwrite .ocm/transport.ctf oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh || true
}

# Build all local charts using two-phase parallel approach
build_local_charts() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Building custom local charts...${COL_RES}"

    # Ensure kubeconfig is set
    kind export kubeconfig -n platform-mesh

    # Create prerelease directory
    mkdir -p "$PRERELEASE_DIR"
    rm -f "$PRERELEASE_DIR"/*.tgz
    rm -f "$PRERELEASE_DIR"/*.meta

    # Copy common chart to prerelease directory (used as dependency by other charts)
    rm -rf "$PRERELEASE_DIR/common"
    cp -r "$PROJECT_ROOT/charts/common" "$PRERELEASE_DIR/common"

    # Setup OCM CLI
    setup_ocm_cli
    export_ocm_path

    # Copy templates to pod
    copy_templates_to_pod

    # Phase 1: Prepare and push all charts
    local failed=0

    if [ "$SEQUENTIAL" = "true" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] === Phase 1: Preparing and pushing charts (sequential) ===${COL_RES}"
        for pair in "${CUSTOM_LOCAL_COMPONENTS_CHART_PATHS[@]}"; do
            local comp="${pair%%:*}"
            local chart_dir="${pair#*:}"

            if ! prepare_and_push_chart "$comp" "$chart_dir"; then
                ((failed++))
            fi
        done
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] === Phase 1: Preparing and pushing charts (parallel, max $MAX_PARALLEL concurrent) ===${COL_RES}"
        local running=0
        local pids=()

        for pair in "${CUSTOM_LOCAL_COMPONENTS_CHART_PATHS[@]}"; do
            local comp="${pair%%:*}"
            local chart_dir="${pair#*:}"

            # Start background job
            prepare_and_push_chart "$comp" "$chart_dir" &
            pids+=($!)
            ((running++))

            # Limit concurrency
            if ((running >= MAX_PARALLEL)); then
                # Wait for any one job to finish
                wait -n 2>/dev/null || true
                ((running--))
            fi
        done

        # Wait for all remaining jobs to complete
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                ((failed++))
            fi
        done
    fi

    if ((failed > 0)); then
        echo -e "${RED}[$(date '+%H:%M:%S')] Phase 1 completed with $failed failures${COL_RES}" >&2
        return 1
    fi
    echo -e "${COL}[$(date '+%H:%M:%S')] Phase 1 completed successfully${COL_RES}"

    # Phase 2: Add all components to OCM CTF sequentially
    echo -e "${COL}[$(date '+%H:%M:%S')] === Phase 2: Adding components to OCM CTF (sequential) ===${COL_RES}"
    for pair in "${CUSTOM_LOCAL_COMPONENTS_CHART_PATHS[@]}"; do
        local comp="${pair%%:*}"
        add_chart_to_ctf "$comp"
    done
    echo -e "${COL}[$(date '+%H:%M:%S')] Phase 2 completed successfully${COL_RES}"

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
