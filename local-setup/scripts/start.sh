#!/bin/bash

DEBUG=${DEBUG:-false}

if [ "${DEBUG}" = "true" ]; then
  set -x
fi

set -e

COL='\033[92m'
RED='\033[91m'
YELLOW='\033[93m'
COL_RES='\033[0m'

KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-900s}"
 KINDEST_VERSION="kindest/node:v1.35.0"

SCRIPT_DIR=$(dirname "$0")

PRERELEASE=false
CACHED=false
EXAMPLE_DATA=false
CONCURRENT=false
REMOTE=false
DEPLOYMENT_TECH="fluxcd"

usage() {
  echo "Usage: $0 [--prerelease] [--cached] [--example-data] [--concurrent] [--remote] [--deployment-tech=fluxcd|argocd] [--help]"
  echo ""
  echo "Options:"
  echo "  --prerelease       Deploy with locally built OCM components instead of released versions"
  echo "  --cached           Use local Docker registry mirrors for faster image pulls"
  echo "  --example-data     Install with example provider data (requires kubectl-kcp plugin)"
  echo "  --concurrent       Run prerelease chart builds in parallel instead of sequentially"
  echo "  --remote           Use remote deployment mode with 2 kind clusters (infra + runtime)"
  echo "  --deployment-tech  Choose deployment technology: fluxcd or argocd (only with --remote). Default: fluxcd"
  echo "  --help             Show this help message"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=true ;;
    --cached) CACHED=true ;;
    --example-data) EXAMPLE_DATA=true ;;
    --concurrent) CONCURRENT=true ;;
    --remote) REMOTE=true ;;
    --deployment-tech=*)
      DEPLOYMENT_TECH="${1#*=}"
      if [ "$DEPLOYMENT_TECH" != "fluxcd" ] && [ "$DEPLOYMENT_TECH" != "argocd" ]; then
        echo "Error: --deployment-tech must be either 'fluxcd' or 'argocd'" >&2
        usage
      fi
      ;;
    --help|-h) usage ;;
    --*) echo "Unknown option: $1" >&2; usage ;;
    *) echo "Ignoring positional arg: $1" ;;
  esac
  shift
done

# Export CONCURRENT for prerelease build scripts
export CONCURRENT

# Source compatibility and environment checks
source "$SCRIPT_DIR/check-wsl-compatibility.sh"
source "$SCRIPT_DIR/check-environment.sh"
source "$SCRIPT_DIR/setup-registry-proxies.sh"
source "$SCRIPT_DIR/setup-prerelease.sh"

if [ "$REMOTE" = true ]; then
  # Remote deployment mode: 2 kind clusters (infra + runtime)
  source "$SCRIPT_DIR/start-remote.sh"
else
  # Single cluster mode
  source "$SCRIPT_DIR/start-local.sh"
fi

exit 0
