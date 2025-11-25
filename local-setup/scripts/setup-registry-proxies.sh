#!/bin/bash

# Registry Proxies Setup Script
# This script sets up Docker/Podman registry proxies for cached mode

COL='\033[92m'
RED='\033[91m'
COL_RES='\033[0m'

setup_registry_proxies() {
    echo -e "${COL}[$(date '+%H:%M:%S')] Setting up registry proxies for cached mode ${COL_RES}"

    # Detect container runtime (docker or podman)
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        CONTAINER_RUNTIME="docker"
    elif command -v podman &> /dev/null && podman info &> /dev/null; then
        CONTAINER_RUNTIME="podman"
    else
        echo -e "${RED}❌ Error: No container runtime available${COL_RES}"
        return 1
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] Using container runtime: $CONTAINER_RUNTIME ${COL_RES}"

    # Start proxy-quay if not already running
    if ! $CONTAINER_RUNTIME ps --format '{{.Names}}' | grep -q '^proxy-quay$'; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Starting proxy-quay registry ${COL_RES}"
        $CONTAINER_RUNTIME run -d --name proxy-quay --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=https://quay.io registry:2
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] proxy-quay registry already running ${COL_RES}"
    fi

    # Start proxy-ghcr if not already running
    if ! $CONTAINER_RUNTIME ps --format '{{.Names}}' | grep -q '^proxy-ghcr$'; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Starting proxy-ghcr registry ${COL_RES}"
        $CONTAINER_RUNTIME run -d --name proxy-ghcr --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=https://ghcr.io registry:2
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] proxy-ghcr registry already running ${COL_RES}"
    fi

    # Start proxy-k8s-io if not already running
    if ! $CONTAINER_RUNTIME ps --format '{{.Names}}' | grep -q '^proxy-k8s-io$'; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Starting proxy-k8s-io registry ${COL_RES}"
        $CONTAINER_RUNTIME run -d --name proxy-k8s-io --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=https://registry.k8s.io registry:2
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] proxy-k8s-io registry already running ${COL_RES}"
    fi

    return 0
}

# Export function so it can be used by other scripts
export -f setup_registry_proxies