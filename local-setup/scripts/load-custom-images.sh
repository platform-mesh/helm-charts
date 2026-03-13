#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
# This script is sourced by start.sh to load custom Docker images into the Kind cluster.
# Copy this file to load-custom-images.sh and customize it for your needs.
# The load-custom-images.sh file is gitignored, so your local changes won't be committed.
#
# Usage:
#   cp load-custom-images.sh.example load-custom-images.sh
#   # Edit load-custom-images.sh with your custom images
#   task local-setup:iterate

chart_app_version() {
    local chart="$1"
    local chartYaml="$SCRIPT_DIR/../../charts/$chart/Chart.yaml"
    if ! test -f "$chartYaml"; then
        echo "Chart.yaml '$chartYaml' not found"
        exit 1
    fi
    # awk -F: '/^appVersion/ { print $2 }' "$chartYaml"
    yq '.appVersion' "$chartYaml"
}

build_and_load() {
    local app="$1"
    local version="$(chart_app_version "$app")"
    local image="ghcr.io/platform-mesh/$app:$version"
    ( cd "$SCRIPT_DIR/../../../$app" && docker build -t "$image" . )
    kind load docker-image "$image" -n platform-mesh
}

build_and_load platform-mesh-operator

kind load docker-image ghcr.io/platform-mesh/upstream-images/postgresql:17.6.0-debian-12-r4 -n platform-mesh
