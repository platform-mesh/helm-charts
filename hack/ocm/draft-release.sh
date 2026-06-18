#!/usr/bin/env bash
set -euo pipefail

# Script to orchestrate the draft release creation process
# Usage: ./draft-release.sh <from-version> <to-version> [--create]

FROM_VERSION="${1:-}"
TO_VERSION="${2:-}"
DRY_RUN="true"

# Parse flags
for arg in "$@"; do
  case $arg in
    --create)
      DRY_RUN="false"
      shift
      ;;
  esac
done

if [[ -z "$FROM_VERSION" ]] || [[ -z "$TO_VERSION" ]]; then
  echo "Error: Both from-version and to-version are required" >&2
  echo "Usage: $0 <from-version> <to-version> [--create]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  Initial release (dry-run, default): $0 0.0.0 0.1.0" >&2
  echo "  Initial release (create): $0 0.0.0 0.1.0 --create" >&2
  echo "  Subsequent release: $0 0.1.0 0.2.0 --create" >&2
  exit 1
fi

# Extract release version (strip RC suffix if present)
RELEASE_VERSION="${TO_VERSION%%-rc.*}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Platform Mesh OCM Draft Release Creator ===" >&2
echo "" >&2
echo "Version: $RELEASE_VERSION (from $TO_VERSION)" >&2
echo "Repository: platform-mesh/helm-charts" >&2
echo "Dry run: $DRY_RUN" >&2
echo "" >&2

# Step 1: Validate prerequisites
echo "[1/6] Validating prerequisites..." >&2
GH_VERSION=$(gh --version 2>&1 | head -1 | awk '{print $3}')
JQ_VERSION=$(jq --version 2>&1)
YQ_VERSION=$(yq --version 2>&1 | head -1 | awk '{print $NF}')

echo "  ✓ GitHub CLI: $GH_VERSION" >&2
echo "  ✓ jq: $JQ_VERSION" >&2
echo "  ✓ yq: $YQ_VERSION" >&2

if command -v ocm &> /dev/null; then
  OCM_VERSION=$(ocm version 2>&1 | grep -oP 'Version:\s+\K[^\s]+' || echo "unknown")
  echo "  ✓ OCM CLI: $OCM_VERSION" >&2
else
  echo "  ⚠ OCM CLI: not found (optional)" >&2
fi

if gh auth status &>/dev/null; then
  echo "  ✓ GitHub authenticated" >&2
else
  echo "  ✗ GitHub not authenticated" >&2
  exit 1
fi
echo "" >&2

# Step 2: Fetch component versions
echo "[2/6] Fetching component versions..." >&2
"$SCRIPT_DIR/fetch-versions.sh" "$FROM_VERSION" "$TO_VERSION" 2>&1 | grep -E "(Found|Fetching|✓)" | sed 's/^/  /' >&2 || true

if [ -f generated/component-versions.json ]; then
  echo "  ✓ Component versions fetched successfully" >&2
  echo -n "  ✓ Found " >&2
  jq -r '.current_release_components | length' generated/component-versions.json >&2
  echo " current release components" >&2
else
  echo "  ✗ Failed to fetch component versions" >&2
  exit 1
fi
echo "" >&2

# Step 3: Generate changelog
echo "[3/6] Generating changelog..." >&2
"$SCRIPT_DIR/generate-changelog.sh" 2>&1 | grep -E "(Analyzing|Fetching|✓)" | head -10 | sed 's/^/  /' >&2 || true

if [ -f generated/changelog.json ]; then
  echo "  ✓ Changelog generated successfully" >&2
  echo -n "  ✓ Platform-mesh changes: " >&2
  jq -r '.changes | length' generated/changelog.json >&2
  echo -n "  ✓ Third-party changes: " >&2
  jq -r '.third_party_changes | length' generated/changelog.json >&2
else
  echo "  ✗ Failed to generate changelog" >&2
  exit 1
fi
echo "" >&2

# Step 4: Format release notes
echo "[4/6] Formatting release notes..." >&2
"$SCRIPT_DIR/format-notes.sh" "$RELEASE_VERSION" 2>&1 | grep -E "(Formatting|Writing|✓)" | sed 's/^/  /' >&2 || true

if [ -f dist/release-notes.md ]; then
  echo "  ✓ Release notes formatted successfully" >&2
  echo -n "  ✓ Generated " >&2
  wc -l < dist/release-notes.md >&2
  echo " lines" >&2
else
  echo "  ✗ Failed to format release notes" >&2
  exit 1
fi
echo "" >&2

# Step 5: Validate links (skip for now as it's slow)
echo "[5/6] Validating links..." >&2
echo "  ⚠ Link validation skipped (long-running, non-blocking)" >&2
echo "" >&2

# Step 6: Create draft release
echo "[6/6] Creating draft release..." >&2
if [[ "$DRY_RUN" == "true" ]]; then
  "$SCRIPT_DIR/create-release.sh" "$RELEASE_VERSION" dist/release-notes.md
else
  "$SCRIPT_DIR/create-release.sh" "$RELEASE_VERSION" dist/release-notes.md --create
fi
