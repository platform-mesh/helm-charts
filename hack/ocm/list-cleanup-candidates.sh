#!/usr/bin/env bash
set -euo pipefail

# Script to list and optionally delete OCM component tags that are candidates for cleanup.
# Deletion requires --delete flag and user confirmation. Each tag is deleted individually
# via skopeo (one tag at a time) — the component itself and other tags are never touched.
#
# Cleanup strategy:
# - Keep all full release tags (e.g., 0.1.0)
# - Keep -rc and -build tags for the LATEST full release
# - Mark older -rc and -build tags as candidates for deletion

REPO="${REPO:-ghcr.io/platform-mesh}"
COMPONENT="${COMPONENT:-github.com/platform-mesh/test-component}"
TARGET_RELEASE="${TARGET_RELEASE:-}"
DELETE=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --delete) DELETE=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# OCM components are stored in the registry under <repo>/component-descriptors/<component>
# e.g., ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh
OCI_PATH="${REPO}/component-descriptors/${COMPONENT}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================="
echo "OCM Component Tag Cleanup Candidate Analysis"
echo "================================================================="
echo ""
echo "Repository: ${REPO}"
echo "Component:  ${COMPONENT}"
echo "OCI path:   ${OCI_PATH}"
if [ -n "$TARGET_RELEASE" ]; then
    echo "Target release: ${TARGET_RELEASE}"
fi
echo ""
echo -e "${YELLOW}NOTE: This is a READ-ONLY analysis. No tags will be deleted.${NC}"
echo -e "${YELLOW}      Run with --delete to delete the candidates after confirmation.${NC}"
echo ""

# Check if skopeo is available
if ! command -v skopeo &> /dev/null; then
    echo -e "${RED}Error: skopeo not found. Please install it first.${NC}"
    exit 1
fi
echo ""

# Use skopeo to list all tags directly from the OCI registry.
# skopeo handles pagination automatically and returns all tags.
ALL_TAGS_JSON=$(skopeo list-tags "docker://${OCI_PATH}" 2>/dev/null || true)

if [ -z "$ALL_TAGS_JSON" ]; then
    echo -e "${RED}Error: Could not fetch tags from ${OCI_PATH}${NC}"
    echo "Authenticate first with: skopeo login ${REPO%%/*}"
    exit 1
fi

# Filter tags
if [ -n "$TARGET_RELEASE" ]; then
    echo "Filtering for tags related to release: ${TARGET_RELEASE}"
    ALL_VERSIONS=$(echo "$ALL_TAGS_JSON" | jq -r '.Tags[]' | grep -E "^${TARGET_RELEASE}(-rc\.[0-9]+|-build\.[0-9]+)?$" | sort -V || true)
else
    ALL_VERSIONS=$(echo "$ALL_TAGS_JSON" | jq -r '.Tags[]' | sort -V)
fi

if [ -z "$ALL_VERSIONS" ]; then
    echo -e "${RED}Error: No matching tags found in ${OCI_PATH}${NC}"
    exit 1
fi

TOTAL_COUNT=$(echo "$ALL_VERSIONS" | wc -l)
echo "Total tags found: ${TOTAL_COUNT}"
echo ""

# Separate versions into categories
FULL_RELEASES=()
RC_TAGS=()
BUILD_TAGS=()

while IFS= read -r version; do
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        FULL_RELEASES+=("$version")
    elif [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$ ]]; then
        RC_TAGS+=("$version")
    elif [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-build\.[0-9]+$ ]]; then
        BUILD_TAGS+=("$version")
    fi
done <<< "$ALL_VERSIONS"

echo "================================================================="
echo "Version breakdown:"
echo "================================================================="
echo -e "${GREEN}Full releases:${NC}    ${#FULL_RELEASES[@]}"
echo -e "${BLUE}RC tags:${NC}          ${#RC_TAGS[@]}"
echo -e "${BLUE}Build tags:${NC}       ${#BUILD_TAGS[@]}"
echo ""

# Find the latest full release
if [ -n "$TARGET_RELEASE" ]; then
    # User specified a target release
    LATEST_RELEASE="$TARGET_RELEASE"
    echo -e "${GREEN}Target release: ${LATEST_RELEASE}${NC}"
elif [ ${#FULL_RELEASES[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No full release tags found${NC}"
    LATEST_RELEASE=""
else
    LATEST_RELEASE=$(printf '%s\n' "${FULL_RELEASES[@]}" | sort -V | tail -1)
    echo -e "${GREEN}Latest full release: ${LATEST_RELEASE}${NC}"
fi
echo ""

echo ""

# Determine which tags to keep and which are candidates for cleanup
KEEP_COUNT=0
CLEANUP_COUNT=0
KEEP_TAGS=()
CLEANUP_TAGS=()

if [ -n "$TARGET_RELEASE" ]; then
    # When targeting a specific release, mark ALL rc/build tags as cleanup candidates
    # and keep only the full release (if it exists)
    for version in "${FULL_RELEASES[@]}"; do
        KEEP_TAGS+=("$version")
        KEEP_COUNT=$((KEEP_COUNT + 1))
    done

    for version in "${RC_TAGS[@]}"; do
        CLEANUP_TAGS+=("$version")
        CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
    done

    for version in "${BUILD_TAGS[@]}"; do
        CLEANUP_TAGS+=("$version")
        CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
    done
else
    # Keep all full releases
    for version in "${FULL_RELEASES[@]}"; do
        KEEP_TAGS+=("$version")
        KEEP_COUNT=$((KEEP_COUNT + 1))
    done

    # Process RC tags
    for version in "${RC_TAGS[@]}"; do
        # Extract base version (e.g., 0.1.0 from 0.1.0-rc.1)
        BASE_VERSION="${version%-rc.*}"

        # Keep RC tags only if they match the latest release
        if [ "$BASE_VERSION" == "$LATEST_RELEASE" ]; then
            KEEP_TAGS+=("$version")
            KEEP_COUNT=$((KEEP_COUNT + 1))
        else
            CLEANUP_TAGS+=("$version")
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        fi
    done

    # Process build tags
    for version in "${BUILD_TAGS[@]}"; do
        # Extract base version (e.g., 0.1.0 from 0.1.0-build.1)
        BASE_VERSION="${version%-build.*}"

        # Keep build tags only if they match the latest release
        if [ "$BASE_VERSION" == "$LATEST_RELEASE" ]; then
            KEEP_TAGS+=("$version")
            KEEP_COUNT=$((KEEP_COUNT + 1))
        else
            CLEANUP_TAGS+=("$version")
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        fi
    done
fi

echo "================================================================="
echo "Analysis Summary:"
echo "================================================================="
if [ -n "$TARGET_RELEASE" ]; then
    echo -e "${GREEN}Tags to KEEP:${NC}      ${KEEP_COUNT} (release ${TARGET_RELEASE})"
    echo -e "${RED}Cleanup candidates:${NC} ${CLEANUP_COUNT} (old rc/build tags for ${TARGET_RELEASE})"
else
    echo -e "${GREEN}Tags to KEEP:${NC}      ${KEEP_COUNT} (all full releases + rc/build for latest release)"
    echo -e "${RED}Cleanup candidates:${NC} ${CLEANUP_COUNT} (old rc/build tags)"
fi
echo ""

# Always show the tag lists if there are any
if [ ${CLEANUP_COUNT} -gt 0 ]; then
    echo "================================================================="
    echo "Tags That Would Be DELETED (${CLEANUP_COUNT} tags):"
    echo "================================================================="
    printf '%s\n' "${CLEANUP_TAGS[@]}" | sort -V
    echo ""
fi

if [ ${KEEP_COUNT} -gt 0 ]; then
    echo "================================================================="
    echo "Tags That Would Be KEPT (${KEEP_COUNT} tags):"
    echo "================================================================="
    printf '%s\n' "${KEEP_TAGS[@]}" | sort -V
    echo ""
fi

if [ ${CLEANUP_COUNT} -gt 0 ]; then
    # Calculate potential reduction
    REDUCTION_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($CLEANUP_COUNT / $TOTAL_COUNT) * 100}")
    echo -e "${YELLOW}Cleanup would reduce tag count by ${CLEANUP_COUNT} tags (${REDUCTION_PERCENT}%)${NC}"
    if [ -n "$TARGET_RELEASE" ]; then
        echo -e "${YELLOW}Remaining tags: ${KEEP_COUNT} (release ${TARGET_RELEASE})${NC}"
    else
        echo -e "${YELLOW}Remaining tags: ${KEEP_COUNT} (${#FULL_RELEASES[@]} releases + latest prerelease tags)${NC}"
    fi
else
    echo -e "${GREEN}No cleanup candidates found.${NC}"
fi

echo ""
echo "================================================================="

if [ "$DELETE" = true ] && [ ${CLEANUP_COUNT} -gt 0 ]; then
    # Verify gh CLI is authenticated before proceeding
    if ! gh auth status --hostname github.com &>/dev/null; then
        echo -e "${RED}Error: gh CLI is not authenticated. Run: gh auth login${NC}"
        exit 1
    fi

    echo -e "${RED}You are about to delete ${CLEANUP_COUNT} tags from:${NC}"
    echo -e "${RED}  ${OCI_PATH}${NC}"
    echo ""
    echo -e "${RED}This operation cannot be undone.${NC}"
    echo ""
    read -r -p "Type 'yes' to confirm deletion: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    # Derive the GitHub package name from the OCI path:
    # ghcr.io/<owner>/component-descriptors/<component> → owner + package name
    REPO_HOST="${REPO%%/*}"           # ghcr.io
    REPO_OWNER="${REPO#*/}"           # platform-mesh
    PACKAGE_NAME="component-descriptors/${COMPONENT}"
    ENCODED_PACKAGE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${PACKAGE_NAME}', safe=''))")

    # Determine if this is a user or org package
    if gh api "orgs/${REPO_OWNER}" &>/dev/null 2>&1; then
        API_BASE="orgs/${REPO_OWNER}"
    else
        API_BASE="users/${REPO_OWNER}"
    fi

    echo ""
    echo "Fetching package version IDs from GitHub API..."
    ALL_PKG_VERSIONS=$(gh api --paginate "${API_BASE}/packages/container/${ENCODED_PACKAGE}/versions" 2>/dev/null)

    echo "Deleting tags..."
    DELETED=0
    FAILED=0
    for version in "${CLEANUP_TAGS[@]}"; do
        # Find the version ID for this tag
        VERSION_ID=$(echo "$ALL_PKG_VERSIONS" | jq -r ".[] | select(.metadata.container.tags[] == \"${version}\") | .id" 2>/dev/null || true)
        if [ -z "$VERSION_ID" ]; then
            echo -e "  ${RED}✗${NC} ${version} (version ID not found)"
            FAILED=$((FAILED + 1))
            continue
        fi
        if gh api --method DELETE "${API_BASE}/packages/container/${ENCODED_PACKAGE}/versions/${VERSION_ID}" &>/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} ${version}"
            DELETED=$((DELETED + 1))
        else
            echo -e "  ${RED}✗${NC} ${version} (API delete failed)"
            FAILED=$((FAILED + 1))
        fi
    done
    echo ""
    echo "================================================================="
    echo -e "${GREEN}Deleted: ${DELETED} tags${NC}"
    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}Failed:  ${FAILED} tags${NC}"
    fi
    echo "================================================================="
elif [ "$DELETE" = true ] && [ ${CLEANUP_COUNT} -eq 0 ]; then
    echo -e "${GREEN}Nothing to delete.${NC}"
    echo "================================================================="
else
    echo -e "${GREEN}Analysis complete. No changes were made.${NC}"
    echo "================================================================="
fi
