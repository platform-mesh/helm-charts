#!/bin/bash

# Windows/WSL Compatibility Check Script
# This script contains all Windows and WSL-specific compatibility checks and guidance

COL='\033[92m'
RED='\033[91m'
COL_RES='\033[0m'

check_wsl_compatibility() {
    # Detect WSL environment and provide Windows-specific guidance
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo -e "${COL}[$(date '+%H:%M:%S')] WSL environment detected ${COL_RES}"
        
        # Check WSL version for Docker Desktop compatibility
        if command -v wsl.exe &> /dev/null; then
            WSL_VERSION=$(wsl.exe --version 2>/dev/null | grep "WSL version" | sed 's/.*: //' || echo "unknown")
            if [[ "$WSL_VERSION" != "unknown" ]]; then
                echo -e "${COL}WSL version: $WSL_VERSION${COL_RES}"
                # Check if version is at least 2.1.5 (required for Docker Desktop integration)
                if [[ "$WSL_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
                    MAJOR=${BASH_REMATCH[1]}
                    MINOR=${BASH_REMATCH[2]}
                    PATCH=${BASH_REMATCH[3]}
                    if (( MAJOR < 2 || (MAJOR == 2 && MINOR < 1) || (MAJOR == 2 && MINOR == 1 && PATCH < 5) )); then
                        echo -e "${RED}Warning: WSL version $WSL_VERSION detected. Docker Desktop integration requires WSL 2.1.5 or higher.${COL_RES}"
                        echo -e "${COL}Please update WSL with: wsl --update${COL_RES}"
                        return 1
                    fi
                fi
            else
                echo -e "${RED}Error: Could not determine WSL version${COL_RES}"
                return 1  # Return 1 to indicate WSL check failure
            fi
        else
            echo -e "${RED}Error: wsl.exe not found in WSL environment${COL_RES}"
            return 1  # Return 1 to indicate WSL check failure
        fi
        
        echo -e "${COL}Note: Ensure Docker Desktop is running with WSL2 integration enabled${COL_RES}"
        echo -e "${COL}For mkcert on Windows, install via: choco install mkcert${COL_RES}"
        
        return 0  # Return 0 to indicate successful WSL checks
    fi
    
    return 0  # Return 0 (success) for non-WSL environments
}

show_wsl_hosts_guidance() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo -e "${COL}WSL Note: You may also need to add this entry to Windows hosts file at: C:\\Windows\\System32\\drivers\\etc\\hosts${COL_RES}"
    fi
}

# Export functions so they can be used by the main script
export -f check_wsl_compatibility
export -f show_wsl_hosts_guidance
