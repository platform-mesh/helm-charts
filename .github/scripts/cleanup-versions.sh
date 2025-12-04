#!/usr/bin/env bash
set -euo pipefail

# Script to cleanup RC and build versions from GitHub Container Registry
# Usage: ./cleanup-versions.sh --prefix <prefix> --range-start <start> --range-end <end> [--dry-run] [--force]
#
# Example:
#   ./cleanup-versions.sh \
#     --prefix "ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh:0.1.0-rc." \
#     --range-start 0 \
#     --range-end 700 \
#     --dry-run

# Parse command line arguments
PREFIX=""
RANGE_START=""
RANGE_END=""
DRY_RUN="false"
FORCE="false"

print_usage() {
  cat <<EOF
Usage: $0 --prefix <prefix> --range-start <start> --range-end <end> [--dry-run] [--force]

Options:
  --prefix        Full package prefix including tag prefix
                  Example: ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh:0.1.0-rc.
  --range-start   Starting number for version range (inclusive)
  --range-end     Ending number for version range (inclusive)
  --dry-run       List matching versions without deleting
  --force         Skip confirmation prompt before deletion

Examples:
  # Dry run to preview what would be deleted
  $0 --prefix "ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh:0.1.0-rc." --range-start 0 --range-end 700 --dry-run

  # Delete with confirmation prompt
  $0 --prefix "ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh:0.1.0-rc." --range-start 0 --range-end 700

  # Force delete without confirmation (use with caution!)
  $0 --prefix "ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh:0.1.0-rc." --range-start 0 --range-end 700 --force
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    --range-start)
      RANGE_START="$2"
      shift 2
      ;;
    --range-end)
      RANGE_END="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$PREFIX" ]] || [[ -z "$RANGE_START" ]] || [[ -z "$RANGE_END" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "" >&2
  print_usage
  exit 1
fi

# Validate range
if [[ "$RANGE_START" -gt "$RANGE_END" ]]; then
  echo "Error: range-start ($RANGE_START) cannot be greater than range-end ($RANGE_END)" >&2
  exit 1
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is required but not found" >&2
  echo "Install from: https://cli.github.com" >&2
  exit 1
fi

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
  echo "Error: Not authenticated with GitHub CLI" >&2
  echo "Run: gh auth login" >&2
  exit 1
fi

# Parse the prefix to extract registry, org, package name, and tag prefix
# Example: ghcr.io/platform-mesh/component-descriptors/github.com/platform-mesh/platform-mesh:0.1.0-rc.
# Registry: ghcr.io
# Org: platform-mesh
# Package path: component-descriptors/github.com/platform-mesh/platform-mesh
# Tag prefix: 0.1.0-rc.

if [[ ! "$PREFIX" =~ ^ghcr\.io/ ]]; then
  echo "Error: Prefix must start with ghcr.io/" >&2
  exit 1
fi

# Remove ghcr.io/ prefix
PREFIX_WITHOUT_REGISTRY="${PREFIX#ghcr.io/}"

# Extract org (first component)
ORG=$(echo "$PREFIX_WITHOUT_REGISTRY" | cut -d'/' -f1)

# Extract everything between org and the colon (package path)
PACKAGE_PATH=$(echo "$PREFIX_WITHOUT_REGISTRY" | sed 's|^[^/]*/||' | cut -d':' -f1)

# Extract tag prefix (everything after the colon)
if [[ "$PREFIX" =~ :([^:]+)$ ]]; then
  TAG_PREFIX="${BASH_REMATCH[1]}"
else
  echo "Error: Could not extract tag prefix from: $PREFIX" >&2
  exit 1
fi

# Encode package path for URL (replace / with %2F)
PACKAGE_NAME_ENCODED=$(echo "$PACKAGE_PATH" | sed 's|/|%2F|g')

echo "=== Platform Mesh Package Cleanup ===" >&2
echo "" >&2
echo "Registry:      ghcr.io" >&2
echo "Organization:  $ORG" >&2
echo "Package:       $PACKAGE_PATH" >&2
echo "Tag prefix:    $TAG_PREFIX" >&2
echo "Version range: $RANGE_START - $RANGE_END" >&2
echo "Dry run:       $DRY_RUN" >&2
echo "" >&2

# Fetch all versions from the package
echo "[1/4] Fetching package versions from registry..." >&2

VERSIONS_JSON=$(gh api "/orgs/$ORG/packages/container/$PACKAGE_NAME_ENCODED/versions" \
  --paginate 2>/dev/null | jq -s 'add' || echo "[]")

if [[ "$VERSIONS_JSON" == "[]" ]] || [[ -z "$VERSIONS_JSON" ]]; then
  echo "Error: Could not fetch versions for package: $PACKAGE_PATH" >&2
  echo "Verify that:" >&2
  echo "  1. The package exists in ghcr.io/$ORG" >&2
  echo "  2. You have access to the package" >&2
  echo "  3. The package name is correct" >&2
  exit 1
fi

# Filter versions matching our criteria
echo "[2/4] Filtering versions matching criteria..." >&2

MATCHING_VERSIONS=()
VERSION_IDS=()

# Build list of versions to delete
for i in $(seq "$RANGE_START" "$RANGE_END"); do
  TAG_NAME="${TAG_PREFIX}${i}"

  # Find the version ID for this tag
  VERSION_ID=$(echo "$VERSIONS_JSON" | jq -r \
    --arg tag "$TAG_NAME" \
    '.[] | select(.metadata.container.tags[]? == $tag) | .id' | head -1)

  if [[ -n "$VERSION_ID" ]]; then
    MATCHING_VERSIONS+=("$TAG_NAME")
    VERSION_IDS+=("$VERSION_ID")
  fi
done

TOTAL_COUNT=${#MATCHING_VERSIONS[@]}

if [[ $TOTAL_COUNT -eq 0 ]]; then
  echo "" >&2
  echo "No matching versions found in the specified range." >&2
  echo "Searched for tags: ${TAG_PREFIX}${RANGE_START} to ${TAG_PREFIX}${RANGE_END}" >&2
  exit 0
fi

echo "  Found $TOTAL_COUNT matching version(s)" >&2
echo "" >&2

# Display versions to be deleted
echo "[3/4] Versions to be deleted:" >&2
echo "" >&2

# Show first 10 and last 10 if more than 20
if [[ $TOTAL_COUNT -le 20 ]]; then
  for version in "${MATCHING_VERSIONS[@]}"; do
    echo "  - $version" >&2
  done
else
  echo "  First 10:" >&2
  for i in {0..9}; do
    echo "    - ${MATCHING_VERSIONS[$i]}" >&2
  done
  echo "  ..." >&2
  echo "  Last 10:" >&2
  for i in $(seq $((TOTAL_COUNT - 10)) $((TOTAL_COUNT - 1))); do
    echo "    - ${MATCHING_VERSIONS[$i]}" >&2
  done
fi

echo "" >&2
echo "Total: $TOTAL_COUNT version(s)" >&2
echo "" >&2

# Dry run mode - exit here
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN MODE ===" >&2
  echo "No versions were deleted. Run without --dry-run to perform deletion." >&2
  exit 0
fi

# Confirmation prompt (unless --force)
if [[ "$FORCE" != "true" ]]; then
  echo "WARNING: This will permanently delete $TOTAL_COUNT package version(s)!" >&2
  echo "This action CANNOT be undone." >&2
  echo "" >&2
  read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
  echo "" >&2

  if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deletion cancelled." >&2
    exit 0
  fi
fi

# Delete versions
echo "[4/4] Deleting versions..." >&2
echo "" >&2

SUCCESS_COUNT=0
FAILURE_COUNT=0
FAILED_VERSIONS=()

for i in "${!VERSION_IDS[@]}"; do
  VERSION_ID="${VERSION_IDS[$i]}"
  TAG_NAME="${MATCHING_VERSIONS[$i]}"
  CURRENT=$((i + 1))

  # Progress indicator
  echo -ne "  Progress: [$CURRENT/$TOTAL_COUNT] Deleting $TAG_NAME..." >&2

  # Delete the version
  if gh api -X DELETE "/orgs/$ORG/packages/container/$PACKAGE_NAME_ENCODED/versions/$VERSION_ID" &> /dev/null; then
    echo " ✓" >&2
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo " ✗" >&2
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_VERSIONS+=("$TAG_NAME")
  fi

  # Add small delay to avoid rate limiting (if deleting many versions)
  if [[ $TOTAL_COUNT -gt 100 ]] && [[ $((CURRENT % 50)) -eq 0 ]]; then
    echo "  (Pausing briefly to avoid rate limiting...)" >&2
    sleep 2
  fi
done

echo "" >&2
echo "=== Deletion Complete ===" >&2
echo "" >&2
echo "Successfully deleted: $SUCCESS_COUNT version(s)" >&2

if [[ $FAILURE_COUNT -gt 0 ]]; then
  echo "Failed to delete:     $FAILURE_COUNT version(s)" >&2
  echo "" >&2
  echo "Failed versions:" >&2
  for version in "${FAILED_VERSIONS[@]}"; do
    echo "  - $version" >&2
  done
  exit 1
fi

echo "" >&2
echo "All versions deleted successfully!" >&2
