#!/bin/bash

# macOS Virtualization Framework Check Script
# This script checks which virtualization framework is being used on macOS
# and warns users if QEMU is detected instead of Apple Virtualization Framework (VZ)

COL='\033[92m'
RED='\033[91m'
YELLOW='\033[93m'
COL_RES='\033[0m'

check_docker_desktop_virtualization() {
    # Check Docker Desktop settings for virtualization framework
    # Try both possible filenames
    local settings_file=""
    if [ -f "$HOME/Library/Group Containers/group.com.docker/settings-store.json" ]; then
        settings_file="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
    elif [ -f "$HOME/Library/Group Containers/group.com.docker/settings.json" ]; then
        settings_file="$HOME/Library/Group Containers/group.com.docker/settings.json"
    else
        echo "unknown"
        return
    fi

    # Check for UseVirtualizationFramework or useVirtualizationFramework field
    if grep -qi '"UseVirtualizationFramework"[[:space:]]*:[[:space:]]*true' "$settings_file" 2>/dev/null || \
       grep -qi '"useVirtualizationFramework"[[:space:]]*:[[:space:]]*true' "$settings_file" 2>/dev/null; then
        echo "vz"
        return
    elif grep -qi '"UseVirtualizationFramework"[[:space:]]*:[[:space:]]*false' "$settings_file" 2>/dev/null || \
         grep -qi '"useVirtualizationFramework"[[:space:]]*:[[:space:]]*false' "$settings_file" 2>/dev/null; then
        echo "qemu"
        return
    fi

    echo "unknown"
}

check_podman_virtualization() {
    # Check Podman machine configuration
    if ! command -v podman &> /dev/null; then
        echo "unknown"
        return
    fi

    # Try to get machine info
    local machine_info=$(podman machine inspect 2>/dev/null | head -20)
    if [ -n "$machine_info" ]; then
        if echo "$machine_info" | grep -qi '"vmType"[[:space:]]*:[[:space:]]*"applehv"'; then
            echo "vz"
            return
        elif echo "$machine_info" | grep -qi '"vmType"[[:space:]]*:[[:space:]]*"qemu"'; then
            echo "qemu"
            return
        fi
    fi

    echo "unknown"
}

show_docker_desktop_guidance() {
    echo -e "${YELLOW}To switch to Apple Virtualization Framework in Docker Desktop:${COL_RES}"
    echo -e "${YELLOW}  1. Open Docker Desktop${COL_RES}"
    echo -e "${YELLOW}  2. Go to Settings → General${COL_RES}"
    echo -e "${YELLOW}  3. Enable 'Use Virtualization framework' or 'VirtioFS'${COL_RES}"
    echo -e "${YELLOW}  4. Restart Docker Desktop${COL_RES}"
}

show_podman_guidance() {
    echo -e "${YELLOW}To use Apple Virtualization Framework with Podman:${COL_RES}"
    echo -e "${YELLOW}  1. Stop the current machine: podman machine stop${COL_RES}"
    echo -e "${YELLOW}  2. Remove the current machine: podman machine rm${COL_RES}"
    echo -e "${YELLOW}  3. Create new machine with VZ: podman machine init --vm-type=applehv${COL_RES}"
    echo -e "${YELLOW}  4. Start the machine: podman machine start${COL_RES}"
}

check_macos_virtualization() {
    # Check if running on macOS
    if [ "$(uname -s)" != "Darwin" ]; then
        return 0  # Skip check on non-macOS systems
    fi

    local virt_type="unknown"
    local runtime_name=""
    local runtime_detected=false

    # Check which container runtime is available and running
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        runtime_name="Docker Desktop"
        runtime_detected=true
        virt_type=$(check_docker_desktop_virtualization)
    elif command -v podman &> /dev/null && podman info &> /dev/null 2>&1; then
        runtime_name="Podman"
        runtime_detected=true
        virt_type=$(check_podman_virtualization)
    fi

    if [ "$runtime_detected" = false ]; then
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] Could not detect container runtime for virtualization check${COL_RES}"
        return 0
    fi

    # Report findings
    if [ "$virt_type" = "vz" ]; then
        echo -e "${COL}[$(date '+%H:%M:%S')] ✅ Apple Virtualization Framework (VZ) detected for $runtime_name${COL_RES}"
    elif [ "$virt_type" = "qemu" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  WARNING: A different virtualization framework was detected on macOS${COL_RES}"
        echo -e "${YELLOW}Platform-mesh has been tested with Apple Virtualization Framework (VZ).${COL_RES}"
        echo -e "${YELLOW}You may experience issues with other virtualization frameworks.${COL_RES}"
        echo ""

        # Show runtime-specific guidance
        case "$runtime_name" in
            "Docker Desktop")
                show_docker_desktop_guidance
                ;;
            "Podman")
                show_podman_guidance
                ;;
        esac

        echo ""
        echo -e "${YELLOW}To continue anyway, the setup will proceed in 5 seconds...${COL_RES}"
        sleep 5
    else
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  Could not determine virtualization framework for $runtime_name${COL_RES}"
        echo -e "${YELLOW}Platform-mesh has been tested with Apple Virtualization Framework (VZ).${COL_RES}"
        echo -e "${YELLOW}If you experience issues, consider switching to Apple Virtualization Framework (VZ).${COL_RES}"
    fi

    echo ""
    return 0  # Always return 0 to not block the setup
}

# Export function so it can be used by the main script
export -f check_macos_virtualization
