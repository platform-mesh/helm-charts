#!/bin/bash

# OCM CLI Setup Script
# Downloads and sets up the OCM CLI binary if not present

set -e

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
OCM_VERSION="${OCM_VERSION:-0.33.0}"
LOCAL_BIN="${LOCAL_BIN:-$PROJECT_ROOT/bin}"

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

# Detect OS and architecture
detect_platform() {
    local os arch

    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows with Git Bash/MSYS/Cygwin - treat as Linux since running in WSL-like env
            os="linux"
            ;;
        *)      echo -e "${RED}Unsupported OS: $(uname -s)${COL_RES}" >&2; exit 1 ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        arm64|aarch64)  arch="arm64" ;;
        *)              echo -e "${RED}Unsupported architecture: $(uname -m)${COL_RES}" >&2; exit 1 ;;
    esac

    echo "${os}-${arch}"
}

# Setup OCM CLI
setup_ocm_cli() {
    local platform
    platform=$(detect_platform)

    # Create bin directory if needed
    mkdir -p "$LOCAL_BIN"

    # Check if OCM is already installed
    if [ -s "$LOCAL_BIN/ocm" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] OCM CLI already installed at $LOCAL_BIN/ocm${COL_RES}"
        return 0
    fi

    echo -e "${COL}[$(date '+%H:%M:%S')] Downloading OCM CLI v${OCM_VERSION} for ${platform}...${COL_RES}"

    local download_url="https://github.com/open-component-model/ocm/releases/download/v${OCM_VERSION}/ocm-${OCM_VERSION}-${platform}.tar.gz"
    local tmp_file="$LOCAL_BIN/ocm.tar.gz"

    # Download OCM
    if ! curl -o "$tmp_file" -sSL "$download_url"; then
        echo -e "${RED}Failed to download OCM CLI from $download_url${COL_RES}" >&2
        exit 1
    fi

    # Extract and cleanup
    tar -xzf "$tmp_file" -C "$LOCAL_BIN"
    rm -f "$tmp_file"
    chmod +x "$LOCAL_BIN/ocm"
    chmod 755 "$LOCAL_BIN/ocm"

    echo -e "${COL}[$(date '+%H:%M:%S')] OCM CLI installed successfully${COL_RES}"
}

# Verify OCM CLI version
verify_ocm_cli() {
    if [ ! -x "$LOCAL_BIN/ocm" ]; then
        echo -e "${RED}OCM CLI not found or not executable at $LOCAL_BIN/ocm${COL_RES}" >&2
        return 1
    fi

    local installed_version
    installed_version=$("$LOCAL_BIN/ocm" version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    echo -e "${COL}[$(date '+%H:%M:%S')] OCM CLI version: ${installed_version}${COL_RES}"
}

# Export the bin path for use by other scripts
export_ocm_path() {
    export PATH="$LOCAL_BIN:$PATH"
    export OCM_BIN="$LOCAL_BIN/ocm"
}

# Main function
main() {
    setup_ocm_cli
    verify_ocm_cli
    export_ocm_path
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
