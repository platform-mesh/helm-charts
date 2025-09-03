#!/bin/bash

# Environment Checks Script
# This script contains all environment variable and dependency checks

COL='\033[92m'
RED='\033[91m'
COL_RES='\033[0m'

check_github_token() {
    # Check for input argument GH_TOKEN and echo message in case not provided
    if [ -z "${GH_TOKEN}" ]; then
        echo "Please set the 'GH_TOKEN' environment variable with a GitHub token that has 'read:packages' scope."
        exit 1
    fi
    # Set global variable that can be used by the main script
    ghToken=$GH_TOKEN
}

check_github_user() {
    if [ -z "${GH_USER}" ]; then
        if ! command -v gh &> /dev/null; then
            echo "gh CLI could not be found. Either install the gh cli or set the GH_USER environment variable with our GitHub username."
            exit 1
        else
            ghUser=$(gh api user --jq '.login')
        fi
    else
        ghUser=$GH_USER
    fi
    # Make ghUser available globally
}

check_kind_cluster() {
    # Check if kind cluster is already running
    if [ $(kind get clusters | grep -c platform-mesh) -gt 0 ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] Kind cluster already running, using existing ${COL_RES}"
        kind export kubeconfig --name platform-mesh
        return 0  # Return 0 to indicate cluster exists
    fi
    return 1  # Return 1 to indicate cluster doesn't exist
}

check_kind_dependency() {
    if ! command -v kind &> /dev/null; then
        echo -e "${RED}❌ Error: 'kind' (Kubernetes in Docker) is not installed${COL_RES}"
        echo -e "${COL}📦 Kind is required to create local Kubernetes clusters.${COL_RES}"
        echo -e "${COL}📚 Installation guide: https://kind.sigs.k8s.io/docs/user/quick-start/#installation${COL_RES}"
        echo ""
        return 1
    fi
    
    echo -e "${COL}[$(date '+%H:%M:%S')] ✅ Kind is available${COL_RES}"
    return 0
}

check_container_runtime_dependency() {
    local docker_available=false
    local podman_available=false
    local runtime_name=""
    
    # Check for Docker
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            docker_available=true
            runtime_name="Docker"
        fi
    fi
    
    # Check for Podman
    if command -v podman &> /dev/null; then
        if podman info &> /dev/null; then
            podman_available=true
            if [ "$docker_available" = false ]; then
                runtime_name="Podman"
            else
                runtime_name="Docker and Podman"
            fi
        fi
    fi
    
    # If neither is available or running, show error
    if [ "$docker_available" = false ] && [ "$podman_available" = false ]; then
        if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
            echo -e "${RED}❌ Error: Neither 'docker' nor 'podman' is installed${COL_RES}"
            echo -e "${COL}🐳 A container runtime (Docker or Podman) is required for kind to create Kubernetes clusters.${COL_RES}"
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo -e "${COL}📚 For WSL: Install Docker Desktop with WSL2 integration${COL_RES}"
                echo -e "${COL}📚 Docker installation guide: https://docs.docker.com/desktop/wsl/${COL_RES}"
            else
                echo -e "${COL}📚 Docker installation guide: https://docs.docker.com/get-docker/${COL_RES}"
            fi
            echo -e "${COL}📚 Podman installation guide: https://podman.io/getting-started/installation${COL_RES}"
        else
            echo -e "${RED}❌ Error: Container runtime daemon is not running${COL_RES}"
            if command -v docker &> /dev/null; then
                echo -e "${COL}🐳 Docker is installed but not running. Please start Docker and try again.${COL_RES}"
                if grep -qi microsoft /proc/version 2>/dev/null; then
                    echo -e "${COL}💡 For WSL: Ensure Docker Desktop is running on Windows${COL_RES}"
                fi
            fi
            if command -v podman &> /dev/null; then
                echo -e "${COL}🐳 Podman is installed but not running. Please start Podman and try again.${COL_RES}"
                echo -e "${COL}💡 Try: 'podman machine start' or 'systemctl --user start podman.socket'${COL_RES}"
            fi
        fi
        echo ""
        return 1
    fi
    
    echo -e "${COL}[$(date '+%H:%M:%S')] ✅ $runtime_name is available and running${COL_RES}"
    return 0
}

# Maintain backward compatibility
check_docker_dependency() {
    check_container_runtime_dependency
}

setup_mkcert_command() {
    # Check for mkcert binary - prefer system PATH (e.g., Chocolatey install) over bundled version
    if command -v mkcert &> /dev/null; then
        MKCERT_CMD="mkcert"
        echo -e "${COL}[$(date '+%H:%M:%S')] ✅ Using system mkcert${COL_RES}"
    else
        # Check if bundled version exists
        if [ -f "$SCRIPT_DIR/../../bin/mkcert" ]; then
            MKCERT_CMD="$SCRIPT_DIR/../../bin/mkcert"
            echo -e "${COL}[$(date '+%H:%M:%S')] ✅ Using bundled mkcert${COL_RES}"
        else
            echo -e "${RED}❌ Error: 'mkcert' is not installed and bundled version not found${COL_RES}"
            echo -e "${COL}🔐 mkcert is required to generate local SSL certificates.${COL_RES}"
            echo -e "${COL}📚 Installation guide: https://github.com/FiloSottile/mkcert#installation${COL_RES}"
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo -e "${COL}💡 For Windows: Use 'choco install mkcert' or 'scoop install mkcert'${COL_RES}"
            fi
            echo ""
            return 1
        fi
    fi
    return 0
}

check_architecture() {
    # Check architecture for resource selection
    local arch=$(uname -m)
    case "$arch" in
        arm64|aarch64)
            echo "arm64"
            return 0
            ;;
        x86_64|amd64)
            echo "x86_64"
            return 0
            ;;
        *)
            echo -e "${RED}❌ Error: Unsupported architecture '$arch'${COL_RES}"
            echo -e "${COL}💡 Supported architectures: arm64, aarch64, x86_64, amd64${COL_RES}"
            echo -e "${COL}📚 Please check if your architecture has available container images${COL_RES}"
            return 1
            ;;
    esac
}

# Run all environment checks
run_environment_checks() {
    echo -e "${COL}🔍 Checking environment dependencies...${COL_RES}"
    echo ""
    
    local checks_failed=0
    
    # Check GitHub token
    if ! check_github_token; then
        checks_failed=$((checks_failed + 1))
    fi
    
    # Check GitHub user
    if ! check_github_user; then
        checks_failed=$((checks_failed + 1))
    fi
    
    # Check container runtime dependency (Docker or Podman)
    if ! check_container_runtime_dependency; then
        checks_failed=$((checks_failed + 1))
    fi
    
    # Check kind dependency
    if ! check_kind_dependency; then
        checks_failed=$((checks_failed + 1))
    fi
    
    # Check mkcert dependency
    if ! setup_mkcert_command; then
        checks_failed=$((checks_failed + 1))
    fi
    
    # Check architecture compatibility
    ARCH=$(check_architecture)
    if [ $? -ne 0 ]; then
        checks_failed=$((checks_failed + 1))
    else
        echo -e "${COL}[$(date '+%H:%M:%S')] ✅ Architecture: $ARCH${COL_RES}"
    fi
    
    if [ $checks_failed -gt 0 ]; then
        echo -e "${RED}❌ $checks_failed dependency check(s) failed. Please install the missing dependencies and try again.${COL_RES}"
        echo ""
        exit 1
    fi
    
    echo -e "${COL}✅ All environment checks passed!${COL_RES}"
    echo ""
}

# Export functions so they can be used by the main script
export -f check_github_token
export -f check_github_user
export -f check_kind_cluster
export -f check_kind_dependency
export -f check_docker_dependency
export -f check_container_runtime_dependency
export -f setup_mkcert_command
export -f check_architecture
export -f run_environment_checks
