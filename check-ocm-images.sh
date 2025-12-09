#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "==================================================================="
echo "Checking OCM-managed images vs actual cluster images"
echo "==================================================================="
echo ""

# Get all OCM-managed images
echo "Fetching OCM-managed images..."
OCM_IMAGES=$(kubectl get resources -ojson 2>/dev/null | jq -r '.items[] | select(.metadata.labels.artifact == "image") | .status.resource.access.imageReference' | sort -u)

if [ -z "$OCM_IMAGES" ]; then
    echo -e "${YELLOW}Warning: No OCM image resources found${NC}"
    OCM_COUNT=0
else
    OCM_COUNT=$(echo "$OCM_IMAGES" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found $OCM_COUNT OCM-managed images${NC}"
fi

echo ""

# Get all images currently in use on the cluster
echo "Fetching images in use on cluster..."
CLUSTER_IMAGES=$(kubectl get po -A -ojson 2>/dev/null | jq -r '.items[] | .spec.containers[]? | .image' | sort -u)

if [ -z "$CLUSTER_IMAGES" ]; then
    echo -e "${RED}Error: No images found on cluster${NC}"
    exit 1
fi

CLUSTER_COUNT=$(echo "$CLUSTER_IMAGES" | wc -l | tr -d ' ')
echo -e "${GREEN}Found $CLUSTER_COUNT unique images in use${NC}"

echo ""
echo "==================================================================="

# Find images NOT managed by OCM
echo ""
echo -e "${YELLOW}Images NOT managed by OCM:${NC}"
echo "-------------------------------------------------------------------"

UNMANAGED_COUNT=0
UNMANAGED_IMAGES=""

while IFS= read -r cluster_image; do
    [ -z "$cluster_image" ] && continue

    FOUND=false

    if [ -n "$OCM_IMAGES" ]; then
        while IFS= read -r ocm_image; do
            [ -z "$ocm_image" ] && continue

            # Direct match
            if [ "$cluster_image" = "$ocm_image" ]; then
                FOUND=true
                break
            fi

            # Check if cluster image matches OCM image (considering tag differences)
            # Extract repo without tag
            cluster_repo=$(echo "$cluster_image" | sed 's/:[^:]*$//')
            ocm_repo=$(echo "$ocm_image" | sed 's/:[^:]*$//')

            if [ "$cluster_repo" = "$ocm_repo" ]; then
                FOUND=true
                break
            fi
        done <<< "$OCM_IMAGES"
    fi

    if [ "$FOUND" = false ]; then
        echo -e "${RED}✗${NC} $cluster_image"
        UNMANAGED_COUNT=$((UNMANAGED_COUNT + 1))
        UNMANAGED_IMAGES="${UNMANAGED_IMAGES}${cluster_image}\n"
    fi
done <<< "$CLUSTER_IMAGES"

echo "-------------------------------------------------------------------"
echo ""

# Summary
echo "==================================================================="
echo "SUMMARY"
echo "==================================================================="
echo "Total OCM-managed images:     $OCM_COUNT"
echo "Total images in use:          $CLUSTER_COUNT"
echo -e "${RED}Images not managed by OCM:    $UNMANAGED_COUNT${NC}"
echo "==================================================================="

# Optional: Show OCM-managed images
echo ""
read -p "Do you want to see the list of OCM-managed images? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}OCM-managed images:${NC}"
    echo "-------------------------------------------------------------------"
    if [ -n "$OCM_IMAGES" ]; then
        while IFS= read -r ocm_image; do
            [ -z "$ocm_image" ] && continue
            echo -e "${GREEN}✓${NC} $ocm_image"
        done <<< "$OCM_IMAGES"
    else
        echo "None"
    fi
    echo "-------------------------------------------------------------------"
fi

# Exit with error code if there are unmanaged images
if [ $UNMANAGED_COUNT -gt 0 ]; then
    exit 1
else
    echo ""
    echo -e "${GREEN}All images are managed by OCM!${NC}"
    exit 0
fi
