#!/bin/bash
# Checks each OCM component in the local registry and verifies its resources
# are reachable at their stored access addresses.
#
# Usage: ./check-local-resources.sh [--no-ping]
#   --no-ping  Skip the curl reachability check (faster, list only)

set -euo pipefail

REGISTRY="${REGISTRY:-oci-registry-docker-registry.registry.svc.cluster.local}"
NO_PING=false
[[ "${1:-}" == "--no-ping" ]] && NO_PING=true

if [ -z "${NO_COLOR:-}" ]; then
    GREEN='\033[92m'
    RED='\033[91m'
    YELLOW='\033[93m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN='' RED='' YELLOW='' BOLD='' RESET=''
fi

COMPONENTS=(
    # Third-party infrastructure
    github.com/kubernetes-sigs/gateway-api
    github.com/traefik/traefik
    github.com/cert-manager/cert-manager
    github.com/openfga/openfga
    github.com/kcp-dev/kcp-operator
    github.com/kcp-dev/kcp
    github.com/kcp-dev/init-agent
    github.com/kcp-dev/api-syncagent
    github.com/cloudnative-pg/cloudnative-pg
    github.com/gardener/etcd-druid
    github.com/prometheus-community/prometheus-operator-crds
    github.com/prometheus-community/kube-prometheus-stack
    github.com/open-telemetry/opentelemetry-operator
    # Platform Mesh internal
    github.com/platform-mesh/account-operator
    github.com/platform-mesh/example-httpbin-operator
    github.com/platform-mesh/extension-manager-operator
    github.com/platform-mesh/iam-service
    github.com/platform-mesh/iam-ui
    github.com/platform-mesh/infra
    github.com/platform-mesh/keycloak
    github.com/platform-mesh/keycloak-operator
    github.com/platform-mesh/kubernetes-graphql-gateway
    github.com/platform-mesh/marketplace-ui
    github.com/platform-mesh/helm-charts/marketplace-ui
    github.com/platform-mesh/images/marketplace-ui
    github.com/platform-mesh/observability
    github.com/platform-mesh/platform-mesh-operator
    github.com/platform-mesh/portal
    github.com/platform-mesh/prerelease
    github.com/platform-mesh/rebac-authz-webhook
    github.com/platform-mesh/security-operator
    github.com/platform-mesh/terminal-controller-manager
    github.com/platform-mesh/virtual-workspaces
)

# Write the Python helper to a temp file so it doesn't compete for stdin.
# Usage: python3 $PYHELPER <mode> [prefix]
#   mode=resources  — print resource rows from stdin JSON (ocm get componentversions output)
#   mode=refs       — print componentReference names from stdin JSON
PYHELPER=$(mktemp /tmp/ocm-check-XXXXXX.py)
trap 'rm -f "$PYHELPER"' EXIT
cat > "$PYHELPER" <<'PYEOF'
import json, sys

mode   = sys.argv[1] if len(sys.argv) > 1 else 'resources'
prefix = sys.argv[2] if len(sys.argv) > 2 else ''

raw = sys.stdin.read()
if not raw.strip():
    sys.exit(0)
d = json.loads(raw)
items = d.get('items', [])
if not items:
    sys.exit(0)
c = items[0]['component']

if mode == 'refs':
    for ref in c.get('componentReferences', []):
        print(ref['componentName'])
else:
    for r in c.get('resources', []):
        acc   = r.get('access', {})
        atype = acc.get('type', '')
        ref   = (acc.get('imageReference') or acc.get('localReference') or
                 acc.get('repoUrl') or '')
        rel   = r.get('relation', 'external')
        name  = f"{prefix}{r['name']}"
        print(f"{name:40} {r['type']:18} {rel:8} {atype:15} {ref}")
PYEOF

check_ref() {
    local ref="$1"
    local hostpath="${ref#oci://}"
    local host="${hostpath%%/*}"
    local rest="${hostpath#*/}"

    # rest may look like: repo/path:tag@sha256:digest  or  repo/path:tag  or  repo/path
    local repo digest tag url
    if [[ "$rest" == *"@"* ]]; then
        # strip digest suffix, then strip tag suffix from repo
        local beforedigest="${rest%%@*}"
        digest="${rest#*@}"
        repo="${beforedigest%%:*}"
        url="https://${host}/v2/${repo}/manifests/${digest}"
    elif [[ "$rest" == *":"* ]]; then
        repo="${rest%%:*}"
        tag="${rest#*:}"
        url="https://${host}/v2/${repo}/manifests/${tag}"
    else
        url="https://${host}/v2/${rest}/tags/list"
    fi

    # Run curl inside the pod — the registry hostname is only resolvable in-cluster
    kubectl exec ocm-transfer-pod -n default -- \
        curl -sk -o /dev/null -w "%{http_code}" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, */*" \
        --max-time 5 "$url" 2>/dev/null
}

pass=0
fail=0
skip=0

for component in "${COMPONENTS[@]}"; do
    data=$(kubectl exec ocm-transfer-pod -n default -- \
        ocm get componentversions "$component" \
        --repo "oci://$REGISTRY/platform-mesh" \
        -o json 2>/dev/null) || true

    if [[ -z "$data" ]] || ! echo "$data" | python3 "$PYHELPER" > /dev/null 2>&1; then
        echo -e "${YELLOW}SKIP${RESET} $component (not found or empty)"
        skip=$((skip+1))
        continue
    fi

    echo -e "\n${BOLD}${component}${RESET}"
    rows=$(echo "$data" | python3 "$PYHELPER" resources)

    # If the component has no direct resources, follow its componentReferences one level deep
    if [[ -z "$rows" ]]; then
        while IFS= read -r refname; do
            [[ -z "$refname" ]] && continue
            refdata=$(kubectl exec ocm-transfer-pod -n default -- \
                ocm get componentversions "$refname" \
                --repo "oci://$REGISTRY/platform-mesh" \
                -o json 2>/dev/null) || true
            [[ -z "$refdata" ]] && continue
            refrows=$(echo "$refdata" | python3 "$PYHELPER" resources "${refname##*/}/")
            rows="${rows}${refrows}"$'\n'
        done < <(echo "$data" | python3 "$PYHELPER" refs)
    fi

    echo "$rows" | grep -v '^$' | column -t

    $NO_PING && continue

    while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        name=$(echo "$row"  | awk '{print $1}')
        atype=$(echo "$row" | awk '{print $4}')
        ref=$(echo "$row"   | awk '{print $5}')

        [[ "$atype" != "ociArtifact" ]] && continue
        [[ -z "$ref" ]]                 && continue

        status=$(check_ref "$ref")
        if [[ "$status" =~ ^2 ]]; then
            echo -e "  ${GREEN}✓${RESET} $name  HTTP $status"
            pass=$((pass+1))
        else
            echo -e "  ${RED}✗${RESET} $name  HTTP $status  $ref"
            fail=$((fail+1))
        fi
    done <<< "$rows"
done

echo ""
echo -e "${BOLD}Summary:${RESET}  ${GREEN}${pass} reachable${RESET}  ${RED}${fail} unreachable${RESET}  ${YELLOW}${skip} skipped${RESET}"
[[ $fail -gt 0 ]] && exit 1 || exit 0
