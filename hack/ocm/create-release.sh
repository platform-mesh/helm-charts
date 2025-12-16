#!/usr/bin/env bash
set -euo pipefail

# Script to create a draft GitHub release
# Usage: ./create-release.sh <version> <notes-file> [--create]

VERSION="${1:-}"
NOTES_FILE="${2:-dist/release-notes.md}"
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

if [[ -z "$VERSION" ]]; then
  echo "Error: Version required" >&2
  echo "Usage: $0 <version> [notes-file] [--create]" >&2
  exit 1
fi

if [[ ! -f "$NOTES_FILE" ]]; then
  echo "Error: Release notes file not found: $NOTES_FILE" >&2
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

# Repository details
REPO="platform-mesh/ocm"

echo "=== Creating Draft Release ===" >&2
echo "Version: $VERSION" >&2
echo "Repository: $REPO" >&2
echo "Dry run: $DRY_RUN" >&2
echo >&2

# Check if release already exists
if gh release view "$VERSION" --repo "$REPO" &> /dev/null; then
  echo "Error: Release $VERSION already exists in $REPO" >&2
  echo "View it at: https://github.com/$REPO/releases/tag/$VERSION" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN MODE ===" >&2
  echo "Would create draft release with the following details:" >&2
  echo >&2
  echo "----------------------------------------" >&2
  echo "Version: $VERSION" >&2
  echo "Title: Platform Mesh OCM Component $VERSION" >&2
  echo "Repository: $REPO" >&2
  echo "Draft: Yes" >&2
  echo "Release Notes File: $NOTES_FILE" >&2
  echo "----------------------------------------" >&2
  echo >&2
  echo "✓ Release notes are ready for preview at: $NOTES_FILE" >&2
  echo "To create this release for real, run with --create" >&2
  exit 0
fi

# Create the draft release
echo "Creating draft release..." >&2

release_url=$(gh release create "$VERSION" \
  --repo "$REPO" \
  --draft \
  --title "Platform Mesh OCM Component $VERSION" \
  --notes-file "$NOTES_FILE" 2>&1)

if [[ $? -eq 0 ]]; then
  echo >&2
  echo "✓ Draft release created successfully!" >&2
  echo >&2
  echo "View at: https://github.com/$REPO/releases/tag/$VERSION" >&2
  echo >&2
  echo "Next steps:" >&2
  echo "  1. Review the release notes in GitHub" >&2
  echo "  2. Edit if needed" >&2
  echo "  3. Publish when ready" >&2
  echo >&2
  echo "https://github.com/$REPO/releases/tag/$VERSION"
else
  echo "Error creating release: $release_url" >&2
  exit 1
fi