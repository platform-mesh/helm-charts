#!/usr/bin/env bash
set -euo pipefail

# Script to validate all links in the release notes using markdown-link-check
# Usage: ./validate-links.sh <release-notes-file>

RELEASE_NOTES_FILE="${1:-dist/release-notes.md}"

if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "Error: Release notes file not found: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

# Check if markdown-link-check is installed
if ! command -v markdown-link-check &> /dev/null; then
  echo "Error: markdown-link-check is not installed" >&2
  echo "Install with: npm install -g markdown-link-check" >&2
  echo "or: npm install markdown-link-check" >&2
  exit 1
fi

echo "=== Validating Links in Release Notes ===" >&2
echo >&2

# Determine config file location (support both repo root and current directory)
CONFIG_FILE=".markdown-link-check.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  # Try repo root if running from subdirectory
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  CONFIG_FILE="$REPO_ROOT/.markdown-link-check.json"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Warning: Config file .markdown-link-check.json not found, using defaults" >&2
  markdown-link-check "$RELEASE_NOTES_FILE"
else
  echo "Using config: $CONFIG_FILE" >&2
  markdown-link-check "$RELEASE_NOTES_FILE" --config "$CONFIG_FILE"
fi
