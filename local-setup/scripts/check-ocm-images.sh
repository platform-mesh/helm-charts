#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "==================================================================="
echo "Checking OCM-managed images vs actual cluster images"
echo "==================================================================="
echo ""

# Get all OCM-managed images
echo "Fetching OCM-managed images..."
OCM_IMAGES=$(kubectl get resources -ojson 2>/dev/null | jq -r '.items[] | select(.metadata.annotations.artifact == "image") | .status.resource.access.imageReference' | sort -u)

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

# Find OCM-managed images that are in use (exact tag match only)
echo ""
echo -e "${GREEN}OCM-managed images IN USE on cluster:${NC}"
echo "-------------------------------------------------------------------"

MANAGED_IN_USE_COUNT=0
declare -a MATCHED_CLUSTER_IMAGES

if [ -n "$OCM_IMAGES" ]; then
    while IFS= read -r ocm_image; do
        [ -z "$ocm_image" ] && continue

        # Check for exact match only
        while IFS= read -r cluster_image; do
            [ -z "$cluster_image" ] && continue

            # Direct exact match
            if [ "$cluster_image" = "$ocm_image" ]; then
                echo -e "${GREEN}✓${NC} $ocm_image"
                MANAGED_IN_USE_COUNT=$((MANAGED_IN_USE_COUNT + 1))
                MATCHED_CLUSTER_IMAGES+=("$cluster_image")
                break
            fi
        done <<< "$CLUSTER_IMAGES"
    done <<< "$OCM_IMAGES"
fi

if [ $MANAGED_IN_USE_COUNT -eq 0 ]; then
    echo -e "${YELLOW}None${NC}"
fi

echo "-------------------------------------------------------------------"

# Find OCM-managed images NOT in use (includes different tag versions)
echo ""
echo -e "${YELLOW}OCM-managed images NOT in use on cluster:${NC}"
echo "-------------------------------------------------------------------"

MANAGED_NOT_IN_USE_COUNT=0

if [ -n "$OCM_IMAGES" ]; then
    while IFS= read -r ocm_image; do
        [ -z "$ocm_image" ] && continue

        FOUND=false
        FOUND_DIFF_TAG=""

        # Check each cluster image
        while IFS= read -r cluster_image; do
            [ -z "$cluster_image" ] && continue

            # Exact match means it's in use
            if [ "$cluster_image" = "$ocm_image" ]; then
                FOUND=true
                break
            fi

            # Check if cluster image matches OCM image with different tag
            cluster_repo=$(echo "$cluster_image" | sed 's/:[^:]*$//')
            ocm_repo=$(echo "$ocm_image" | sed 's/:[^:]*$//')

            if [ "$cluster_repo" = "$ocm_repo" ]; then
                FOUND_DIFF_TAG="$cluster_image"
            fi
        done <<< "$CLUSTER_IMAGES"

        if [ "$FOUND" = false ]; then
            if [ -n "$FOUND_DIFF_TAG" ]; then
                echo -e "${YELLOW}○${NC} $ocm_image ${BLUE}(cluster uses different tag: $FOUND_DIFF_TAG)${NC}"
            else
                echo -e "${YELLOW}○${NC} $ocm_image"
            fi
            MANAGED_NOT_IN_USE_COUNT=$((MANAGED_NOT_IN_USE_COUNT + 1))
        fi
    done <<< "$OCM_IMAGES"
fi

if [ $MANAGED_NOT_IN_USE_COUNT -eq 0 ]; then
    echo -e "${GREEN}None - all OCM images are in use with exact tags!${NC}"
fi

echo "-------------------------------------------------------------------"

# Find images NOT managed by OCM
echo ""
echo -e "${RED}Images NOT managed by OCM:${NC}"
echo "-------------------------------------------------------------------"

UNMANAGED_COUNT=0

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
    fi
done <<< "$CLUSTER_IMAGES"

echo "-------------------------------------------------------------------"
echo ""

# Summary
echo "==================================================================="
echo "SUMMARY"
echo "==================================================================="
echo "Total OCM-managed images:               $OCM_COUNT"
echo -e "${GREEN}  - In use on cluster:                  $MANAGED_IN_USE_COUNT${NC}"
echo -e "${YELLOW}  - Not in use on cluster:              $MANAGED_NOT_IN_USE_COUNT${NC}"
echo ""
echo "Total images in use on cluster:         $CLUSTER_COUNT"
echo -e "${GREEN}  - Managed by OCM:                     $MANAGED_IN_USE_COUNT${NC}"
echo -e "${RED}  - Not managed by OCM:                 $UNMANAGED_COUNT${NC}"
echo "==================================================================="

# Exit with error code if there are unmanaged images
if [ $UNMANAGED_COUNT -gt 0 ]; then
    exit 1
else
    echo ""
    echo -e "${GREEN}All images are managed by OCM!${NC}"
    exit 0
fi
