#!/usr/bin/env bash
set -euo pipefail

# Script to generate changelog by analyzing component version changes
# Usage: ./generate-changelog.sh <versions-file> <output-file>

VERSIONS_FILE="${1:-generated/component-versions.json}"
OUTPUT_FILE="${2:-generated/changelog.json}"

if [[ ! -f "$VERSIONS_FILE" ]]; then
  echo "Error: Versions file not found: $VERSIONS_FILE" >&2
  exit 1
fi

# Create generated directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

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

# Fetch release notes for a component from GitHub
fetch_github_release() {
  local org=$1
  local repo=$2
  local version=$3

  # Try to fetch release by tag
  local result
  result=$(gh api "repos/${org}/${repo}/releases" 2>/dev/null | \
    jq ".[] | select(.tag_name == \"${version}\" or .tag_name == \"v${version}\") | {
      name: .name,
      body: .body,
      html_url: .html_url,
      tag_name: .tag_name,
      is_prerelease: .prerelease,
      published_at: .published_at
    }" 2>/dev/null || echo "")

  # Return empty object if no result
  if [[ -z "$result" ]]; then
    echo "{}"
  else
    echo "$result"
  fi
}

# Fetch OCM component details (resources, sources, and raw YAML)
fetch_ocm_component_details() {
  local component=$1
  local version=$2

  if ! command -v ocm &> /dev/null; then
    echo "{}"
    return
  fi

  local result
  result=$(ocm get component "github.com/platform-mesh/${component}:${version}" \
    --repo ghcr.io/platform-mesh -o yaml 2>/dev/null)

  if [[ -z "$result" ]] || [[ "$result" == *"Error"* ]]; then
    echo "{}"
    return
  fi

  # Extract resources and sources using yq
  local resources=$(echo "$result" | yq eval '.component.resources' -o=json 2>/dev/null || echo "[]")
  local sources=$(echo "$result" | yq eval '.component.sources' -o=json 2>/dev/null || echo "[]")

  # Escape raw YAML for JSON (replace newlines with \n and escape quotes)
  local raw_yaml=$(echo "$result" | jq -Rs . 2>/dev/null || echo '""')

  # Combine into single JSON object
  jq -n \
    --argjson resources "$resources" \
    --argjson sources "$sources" \
    --argjson raw_yaml "$raw_yaml" \
    '{resources: $resources, sources: $sources, raw_yaml: $raw_yaml}' 2>/dev/null || echo "{}"
}

# Check if changelog indicates breaking changes
is_breaking_change() {
  local changelog=$1
  if echo "$changelog" | grep -qiE "(breaking|major|BREAKING|MAJOR)"; then
    echo "true"
  else
    echo "false"
  fi
}

# Detect major version bump
is_major_version_bump() {
  local old_ver=$1
  local new_ver=$2

  # Remove 'v' prefix if present
  old_ver=${old_ver#v}
  new_ver=${new_ver#v}

  # Extract major version
  old_major=$(echo "$old_ver" | cut -d. -f1)
  new_major=$(echo "$new_ver" | cut -d. -f1)

  if [[ "$new_major" -gt "$old_major" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Third-party components (should be skipped in changelog generation)
declare -A THIRD_PARTY_COMPONENTS=(
  ["gateway-api"]=1
  ["traefik"]=1
  ["cert-manager"]=1
  ["crossplane"]=1
  ["openfga"]=1
  ["kcp-operator"]=1
  ["etcd-druid"]=1
)

# Main execution
echo "=== Generating Changelog ===" >&2
echo >&2

# Check if there's a previous release to compare against
from_version=$(jq -r '.from_version // ""' "$VERSIONS_FILE")
to_version=$(jq -r '.to_version // ""' "$VERSIONS_FILE")
has_previous_release=false

if [[ "$from_version" != "0.0.0" ]] && [[ -n "$from_version" ]]; then
  has_previous_release=true
  echo "Comparing $from_version -> $to_version" >&2
else
  echo "Initial release: $to_version (showing all components)" >&2
fi

echo >&2

# Initialize output
jq -n '{
  changes: [],
  third_party_changes: []
}' > "$OUTPUT_FILE"

# Track component versions
declare -A first_version
declare -A last_version

# Load current release component versions
curr_components=$(jq -r '.current_release_components | keys[]' "$VERSIONS_FILE" 2>/dev/null || echo "")

while IFS= read -r component; do
  if [[ -z "$component" ]]; then
    continue
  fi

  version=$(jq -r ".current_release_components[\"$component\"]" "$VERSIONS_FILE")
  last_version[$component]="$version"
done <<< "$curr_components"

# If we have a previous release, use it as the baseline for comparison
if [[ "$has_previous_release" == "true" ]]; then
  # Load previous release component versions as the baseline
  prev_components=$(jq -r '.previous_release_components | keys[]' "$VERSIONS_FILE" 2>/dev/null || echo "")

  while IFS= read -r component; do
    if [[ -z "$component" ]]; then
      continue
    fi

    version=$(jq -r ".previous_release_components[\"$component\"]" "$VERSIONS_FILE")
    first_version[$component]="$version"
  done <<< "$prev_components"
else
  # For initial release, there's no previous version
  # We'll show all components as "new"
  for component in "${!last_version[@]}"; do
    first_version[$component]=""
  done
fi

# Generate changelog for each changed component
echo "Fetching changelogs for changed components..." >&2

for component in "${!last_version[@]}"; do
  first_ver="${first_version[$component]:-}"
  last_ver="${last_version[$component]:-}"

  # Skip if version didn't change
  if [[ "$first_ver" == "$last_ver" ]]; then
    continue
  fi

  # Skip third-party components (they're handled separately)
  if [[ -n "${THIRD_PARTY_COMPONENTS[$component]:-}" ]]; then
    continue
  fi

  echo "  $component: $first_ver → $last_ver" >&2

  # Fetch release notes from GitHub
  release_data=$(fetch_github_release "platform-mesh" "$component" "$last_ver")

  # Ensure we have valid JSON (default to empty object if not)
  if [[ -z "$release_data" ]] || ! echo "$release_data" | jq empty 2>/dev/null; then
    release_data="{}"
  fi

  # Fetch OCM component details
  ocm_details=$(fetch_ocm_component_details "$component" "$last_ver")
  if [[ -z "$ocm_details" ]] || ! echo "$ocm_details" | jq empty 2>/dev/null; then
    ocm_details="{}"
  fi

  # Determine if breaking change (skip for initial release)
  is_breaking="false"
  if [[ "$has_previous_release" == "true" ]]; then
    if [[ -n "$release_data" ]] && [[ "$release_data" != "{}" ]]; then
      body=$(echo "$release_data" | jq -r '.body // ""')
      is_breaking=$(is_breaking_change "$body")
    fi

    # Check for major version bump
    if [[ "$is_breaking" == "false" ]]; then
      is_breaking=$(is_major_version_bump "$first_ver" "$last_ver")
    fi
  fi

  # Add to changelog
  jq \
    --arg comp "$component" \
    --arg old_ver "$first_ver" \
    --arg new_ver "$last_ver" \
    --arg breaking "$is_breaking" \
    --argjson release "$release_data" \
    --argjson ocm "$ocm_details" \
    '.changes += [{
      component: $comp,
      old_version: $old_ver,
      new_version: $new_ver,
      is_breaking: ($breaking == "true"),
      release_notes: $release,
      ocm_details: $ocm
    }]' \
    "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
  mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
done

# Sort changes by breaking changes first, then alphabetically
jq '.changes |= sort_by([(if .is_breaking then 0 else 1 end), .component])' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# Analyze third-party component changes
echo "Analyzing third-party component changes..." >&2

current_third_party=$(jq -r '.third_party' "$VERSIONS_FILE")
previous_third_party=$(jq -r '.previous_third_party // {}' "$VERSIONS_FILE")

# Compare third-party versions
third_party_keys=$(echo "$current_third_party" | jq -r 'keys[]' 2>/dev/null || echo "")

while IFS= read -r key; do
  if [[ -z "$key" ]]; then
    continue
  fi

  current_val=$(echo "$current_third_party" | jq -r ".[\"$key\"] // \"\"")
  previous_val=$(echo "$previous_third_party" | jq -r ".[\"$key\"] // \"\"")

  # Skip if no change
  if [[ "$current_val" == "$previous_val" ]] || [[ -z "$current_val" ]]; then
    continue
  fi

  # Add to third-party changes
  jq \
    --arg key "$key" \
    --arg old_val "$previous_val" \
    --arg new_val "$current_val" \
    '.third_party_changes += [{
      component: $key,
      old_version: $old_val,
      new_version: $new_val
    }]' \
    "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
  mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

  if [[ -n "$previous_val" ]]; then
    echo "  $key: $previous_val → $current_val" >&2
  else
    echo "  $key: (new) → $current_val" >&2
  fi
done <<< "$third_party_keys"

# Sort third-party changes alphabetically
jq '.third_party_changes |= sort_by(.component)' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

change_count=$(jq '.changes | length' "$OUTPUT_FILE")
third_party_change_count=$(jq '.third_party_changes | length' "$OUTPUT_FILE")
echo >&2
echo "Found $change_count component change(s)" >&2
echo "Found $third_party_change_count third-party component change(s)" >&2
echo "Changelog saved to: $OUTPUT_FILE" >&2
echo >&2

# Output the JSON to stdout
cat "$OUTPUT_FILE"
