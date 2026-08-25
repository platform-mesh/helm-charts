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
CUSTOM_LOCAL_COMPONENTS="account-operator,example-httpbin-operator,extension-manager-operator,gateway-api-crds,iam-service,iam-ui,infra,keycloak-operator,kro-composition-operator,kubernetes-graphql-gateway,marketplace-ui,observability,platform-mesh-operator,platform-mesh-operator-components,platform-mesh-operator-infra-components,portal,rebac-authz-webhook,security-operator,terminal-controller-manager,virtual-workspaces"

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

# Get kubectl exec flags; should not provide -t because users might have wrapper
# scripts for managed kubectl's or am trying to redirect the output of this script
# to a file.
# Must be called at point of use, not script init, because background jobs lose TTY
get_kubectl_exec_flags() {
    echo "-i"
}

# Update/download the component constructor template
update_constructor() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Preparing component-constructor-prerelease.yaml...${COL_RES}"

    cp "$OCM_DIR/component-constructor-aggregate.yaml" "$OCM_DIR/component-constructor-prerelease.yaml"

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
            kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- ocm transfer component-version --recursive --copy-resources --upload-as ociArtifact "ghcr.io/platform-mesh//$component:$ver" "https://$LOCAL_REGISTRY/platform-mesh"
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
    "$LOCAL_BIN/ocm" --config "$OCM_DIR/config" get component-version --latest "$repo//$component" -o json | jq -r '.[0].component.version'
}

transfer_etcd_druid() {
    local name="$1"
    local ref="$2"
    local ver="$3"

    local cluster_oci="$LOCAL_REGISTRY/platform-mesh"

    # OCM v2 bug: when a component has multiple resources with the same name+version but different
    # extraIdentity (e.g. etcd-druid has helmChart, helmchart-imagemap, and OCI image), the generated
    # transfer spec's GetLocalResource node for the OCI image omits extraIdentity in its query and
    # matches all 3 — causing "found N candidates" regardless of source type.
    # Workaround: generate a dry-run transfer spec locally (where upstream is reachable), strip the
    # helmChart, helmchart-imagemap, and SPDX nodes, copy to pod, and replay the filtered spec.
    # The pod fetches resources directly from upstream (europe-docker.pkg.dev) via GetOCIArtifact nodes.
    # We do NOT pre-transfer from the local CTF cache to OCI first — that would cause OCM to emit
    # CTFGetLocalResource nodes (which carry the same bug) instead of GetOCIArtifact nodes.
    echo -e "${COL}[$(date '+%H:%M:%S')] $name: building filtered transfer spec...${COL_RES}"
    local spec_raw="/tmp/ocm-transfer-spec-${name}-raw.yaml"
    local spec_filtered="/tmp/ocm-transfer-spec-${name}-filtered.yaml"
    # Use a placeholder target for spec generation to avoid network calls to the cluster OCI
    # registry (not reachable locally). The actual target baseUrl is replaced after filtering.
    local spec_target_placeholder="spec-placeholder.local/platform-mesh"
    local cluster_oci_host="${cluster_oci%%/*}"

    "$LOCAL_BIN/ocm" --config "$OCM_DIR/config" transfer component-version \
        --recursive --copy-resources --upload-as ociArtifact --dry-run -o yaml \
        "$ref:$ver" "$spec_target_placeholder" > "$spec_raw" 2>/tmp/ocm-dryrun-${name}.log || true

    if [ -s "$spec_raw" ] && grep -q "transformations:" "$spec_raw"; then
        python3 - "$spec_raw" "$spec_filtered" "spec-placeholder.local" "$cluster_oci_host" << 'PYEOF'
import yaml, sys
with open(sys.argv[1]) as f:
    content = f.read()
# Replace placeholder hostname with actual cluster OCI registry hostname
content = content.replace(sys.argv[3], sys.argv[4])
spec = yaml.safe_load(content)
nodes = spec.get('transformations', [])
# Strip helmchart-imagemap nodes: they use the buggy GetLocalResource path with no extraIdentity.
# Also strip SPDX nodes: they back a multi-manifest OCI index that OCM v2 cannot re-pack.
# HelmChart nodes are kept — with --upload-as ociArtifact they become TransferOCIArtifact
# (direct OCI-to-OCI copy from europe-docker.pkg.dev/charts/...) and don't hit the bug.
strip_ids = {n['id'] for n in nodes if
    'HelmchartImagemap' in n['id'] or 'Spdx' in n['id']}
def strip_refs(obj):
    if isinstance(obj, list):
        return [strip_refs(i) for i in obj if not (isinstance(i, str) and any(s in i for s in strip_ids))]
    elif isinstance(obj, dict):
        return {k: strip_refs(v) for k, v in obj.items()}
    return obj
filtered = [strip_refs(n) for n in nodes if n['id'] not in strip_ids]
for n in filtered:
    if 'dependsOn' in n:
        n['dependsOn'] = [d for d in n['dependsOn'] if d not in strip_ids]
spec['transformations'] = filtered
with open(sys.argv[2], 'w') as f:
    yaml.dump(spec, f, default_flow_style=False)
print(f"Stripped {len(strip_ids)} nodes, {len(filtered)} remaining", file=sys.stderr)
PYEOF
        kubectl cp "$spec_filtered" -n default "ocm-transfer-pod:.ocm/transfer-spec-${name}.yaml"
        kubectl exec -i ocm-transfer-pod -- \
            ocm transfer component-version --transfer-spec ".ocm/transfer-spec-${name}.yaml"
    else
        echo -e "${RED}[$(date '+%H:%M:%S')] $name: dry-run spec generation failed (see /tmp/ocm-dryrun-${name}.log), attempting direct transfer${COL_RES}"
        kubectl exec -i ocm-transfer-pod -- ocm transfer component-version --recursive \
            "$ref:$ver" "$cluster_oci"
    fi
}

# Resolve all component versions
resolve_component_versions() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Resolving component versions...${COL_RES}"

    # Local/remote component versions
    get_component_version account-operator github.com/platform-mesh/account-operator charts/account-operator ACCOUNT_OPERATOR_VERSION
    get_component_version gateway-api-crds github.com/platform-mesh/gateway-api-crds charts/gateway-api-crds GATEWAY_API_CHART_VERSION
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
    export API_SYNCAGENT_COMPONENT_VERSION=$(yq -r '.jobs.ocm.env.API_SYNCAGENT_COMPONENT_VERSION' "$agg")
    export OPENFGA_VERSION=$(yq -r '.jobs.ocm.env.OPENFGA_VERSION' "$agg")
    export OPENFGA_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.OPENFGA_IMAGE_VERSION' "$agg")
    export OPENFGA_POSTGRESQL_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.OPENFGA_POSTGRESQL_IMAGE_VERSION' "$agg")
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

    transfer_etcd_druid etcd-druid \
        europe-docker.pkg.dev/gardener-project/releases//github.com/gardener/etcd-druid \
        "$GARDENER_ETCD_DRUID_VERSION"

    echo -e "${COL}[$(date '+%H:%M:%S')] Finished resolving component versions${COL_RES}"
}

# Pre-populate the local OCI registry with external components that must be present before any
# 'ocm add component-versions' runs (both build_local_charts Phase 2 and build_final_component).
# OCM v2 performs graph discovery against the target repository before constructing — any
# componentReference pointing at a missing component causes an immediate failure.
prefill_ctf() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Pre-filling local OCI registry with external components...${COL_RES}"

    # api-syncagent: referenced by the component-specific constructor for example-httpbin-operator
    # (used in build_local_charts Phase 2) but only built inline during build_final_component().
    # Build it standalone into the OCI registry here so Phase 2 can resolve it.
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- bash -c "cat > .ocm/component-constructor-api-syncagent.yaml << 'EOCTOR'
components:
  - name: github.com/platform-mesh/api-syncagent
    version: \${API_SYNCAGENT_COMPONENT_VERSION}
    provider:
      name: kcp
    resources:
      - name: chart
        type: helmChart
        relation: local
        version: \${API_SYNCAGENT_CHART_VERSION}
        access:
          type: ociArtifact
          imageReference: ghcr.io/platform-mesh/ocm/charts/api-syncagent:\${API_SYNCAGENT_CHART_VERSION}
      - name: image
        type: ociImage
        relation: local
        version: \${API_SYNCAGENT_IMAGE_VERSION}
        access:
          type: ociArtifact
          imageReference: ghcr.io/kcp-dev/api-syncagent:\${API_SYNCAGENT_IMAGE_VERSION}
EOCTOR"
    kubectl exec $(get_kubectl_exec_flags) ocm-transfer-pod -- \
        env \
        API_SYNCAGENT_COMPONENT_VERSION="$API_SYNCAGENT_COMPONENT_VERSION" \
        API_SYNCAGENT_CHART_VERSION="$API_SYNCAGENT_CHART_VERSION" \
        API_SYNCAGENT_IMAGE_VERSION="$API_SYNCAGENT_IMAGE_VERSION" \
        ocm add component-versions \
        --component-version-conflict-policy replace \
        --repository "oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh" \
        --constructor .ocm/component-constructor-api-syncagent.yaml
    echo -e "${COL}[$(date '+%H:%M:%S')] api-syncagent pre-built into local OCI registry${COL_RES}"

    echo -e "${COL}[$(date '+%H:%M:%S')] Local OCI registry pre-fill complete${COL_RES}"
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
        GATEWAY_API_CHART_VERSION="$GATEWAY_API_CHART_VERSION" \
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
        API_SYNCAGENT_COMPONENT_VERSION="$API_SYNCAGENT_COMPONENT_VERSION" \
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
        --repository "oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh" \
        --constructor .ocm/component-constructor-prerelease.yaml

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

    # Export version pins needed by prefill_ctf before build_local_charts runs.
    # The full set is exported later in resolve_component_versions; these are
    # needed early because prefill_ctf must run before Phase 2 of build_local_charts.
    local agg="$PROJECT_ROOT/.github/workflows/ocm-aggregator.yaml"
    export API_SYNCAGENT_CHART_VERSION=$(yq -r '.jobs.ocm.env.API_SYNCAGENT_CHART_VERSION' "$agg")
    export API_SYNCAGENT_IMAGE_VERSION=$(yq -r '.jobs.ocm.env.API_SYNCAGENT_IMAGE_VERSION' "$agg")
    export API_SYNCAGENT_COMPONENT_VERSION=$(yq -r '.jobs.ocm.env.API_SYNCAGENT_COMPONENT_VERSION' "$agg")

    # Pre-populate local OCI registry with externals that component-specific constructors reference.
    # Must happen before build_local_charts Phase 2.
    prefill_ctf

    # Build local charts (writes directly to local OCI registry)
    build_local_charts

    # Resolve component versions
    resolve_component_versions

    # Build final component
    build_final_component

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
