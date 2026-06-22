#!/bin/bash

# Resolve third-party OCM component versions that vary at runtime, before any
# transfers happen. Used in CI to compute actions/cache keys; can also be run
# locally to inspect resolved versions.
#
# Output:
#   - prints "<name>=<version>" lines to stdout (one per resolved component)
#   - if $GITHUB_OUTPUT is set, appends the same as step outputs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/ocm-setup.sh"

LOCAL_BIN="${LOCAL_BIN:-$PROJECT_ROOT/bin}"
OCM_DIR="${OCM_DIR:-$PROJECT_ROOT/.ocm}"

setup_ocm_cli >/dev/null
export_ocm_path

# etcd-druid: --latest from gardener releases
ETCD_DRUID_VERSION=$("$LOCAL_BIN/ocm" --config "$OCM_DIR/config" get componentversions --latest \
    github.com/gardener/etcd-druid --repo europe-docker.pkg.dev/gardener-project/releases -o json \
    | jq -r '.items[0].component.version')

if [ -z "$ETCD_DRUID_VERSION" ] || [ "$ETCD_DRUID_VERSION" = "null" ]; then
    echo "Failed to resolve etcd-druid version" >&2
    exit 1
fi

echo "etcd_druid=$ETCD_DRUID_VERSION"

if [ -n "$GITHUB_OUTPUT" ]; then
    echo "etcd_druid=$ETCD_DRUID_VERSION" >> "$GITHUB_OUTPUT"
fi
