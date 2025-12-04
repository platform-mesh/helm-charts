#!/usr/bin/env bash
set -euo pipefail

# Script to validate all links in the release notes
# Usage: ./validate-links.sh <release-notes-file>

RELEASE_NOTES_FILE="${1:-dist/release-notes.md}"

if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "Error: Release notes file not found: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Validating Links in Release Notes ===" >&2
echo >&2

# Extract all URLs from markdown
# Matches [text](url) format
urls=$(grep -oE '\]\(https?://[^)]+\)' "$RELEASE_NOTES_FILE" | \
  sed 's/^](//' | \
  sed 's/)$//' | \
  sort -u)

if [[ -z "$urls" ]]; then
  echo "No URLs found in release notes" >&2
  exit 0
fi

total_urls=$(echo "$urls" | wc -l | tr -d ' ')
checked=0
valid=0
invalid=0
skipped=0

declare -a invalid_urls
declare -a skipped_urls

echo "Found $total_urls unique URL(s) to validate" >&2
echo >&2

# Validate each URL
while IFS= read -r url; do
  ((checked++))

  # Skip OCI registry URLs (they don't support HTTP HEAD requests)
  if [[ "$url" == ghcr.io/* ]] || [[ "$url" == oci://* ]]; then
    echo "  [$checked/$total_urls] ⏭️  Skipping OCI registry: $url" >&2
    ((skipped++))
    skipped_urls+=("$url")
    continue
  fi

  # Check if URL is accessible
  # Use --head for faster checks, with timeout and retry
  if curl -f -s -L --head --max-time 10 --retry 2 "$url" >/dev/null 2>&1; then
    echo -e "  [$checked/$total_urls] ${GREEN}✓${NC} $url" >&2
    ((valid++))
  else
    echo -e "  [$checked/$total_urls] ${RED}✗${NC} $url" >&2
    ((invalid++))
    invalid_urls+=("$url")
  fi
done <<< "$urls"

echo >&2
echo "=== Validation Summary ===" >&2
echo "Total URLs: $total_urls" >&2
echo -e "${GREEN}Valid: $valid${NC}" >&2
echo -e "${RED}Invalid: $invalid${NC}" >&2
echo -e "${YELLOW}Skipped (OCI): $skipped${NC}" >&2
echo >&2

# Report invalid URLs
if [[ $invalid -gt 0 ]]; then
  echo -e "${RED}⚠️  Invalid URLs found:${NC}" >&2
  for url in "${invalid_urls[@]}"; do
    echo "  - $url" >&2
  done
  echo >&2
  exit 1
fi

# Report skipped URLs
if [[ $skipped -gt 0 ]]; then
  echo -e "${YELLOW}ℹ️  Skipped OCI registry URLs (not HTTP-accessible):${NC}" >&2
  for url in "${skipped_urls[@]}"; do
    echo "  - $url" >&2
  done
  echo >&2
fi

echo -e "${GREEN}✅ All HTTP(S) links are valid!${NC}" >&2
exit 0
