#!/usr/bin/env bash
set -euo pipefail

# Script to fetch component versions from OCM registry
# Usage: ./fetch-versions.sh <from-version> <to-version> [output-file]
#
# For initial release, use: ./fetch-versions.sh 0.0.0 0.1.0
# For subsequent releases, use: ./fetch-versions.sh 0.1.0 0.2.0

FROM_VERSION="${1:-}"
TO_VERSION="${2:-}"
OUTPUT_FILE="${3:-generated/component-versions.json}"

if [[ -z "$FROM_VERSION" ]] || [[ -z "$TO_VERSION" ]]; then
  echo "Error: Both from-version and to-version are required" >&2
  echo "Usage: $0 <from-version> <to-version> [output-file]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  Initial release: $0 0.0.0 0.1.0" >&2
  echo "  Subsequent release: $0 0.1.0 0.2.0" >&2
  exit 1
fi

# Clean up generated directory and recreate it
rm -rf generated
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Third-party components and their sources (static list)
# Note: All platform-mesh components are fetched dynamically from OCM
declare -A THIRD_PARTY_COMPONENTS=(
  ["gateway-api"]="kubernetes-sigs/gateway-api"
  ["traefik"]="traefik/traefik"
  ["cert-manager"]="cert-manager/cert-manager"
  ["openfga"]="openfga/openfga"
  ["kcp-operator"]="kcp-dev/kcp-operator"
  ["etcd-druid"]="gardener/etcd-druid"
)

# Check if OCM CLI is available
if ! command -v ocm &> /dev/null; then
  echo "Warning: OCM CLI not found. Cannot fetch platform-mesh component versions." >&2
  echo "Install from: https://github.com/open-component-model/ocm/releases" >&2
fi

# Find the previous release version to compare against
find_previous_release() {
  local target=$1

  # Check if gh CLI is available
  if ! command -v gh &> /dev/null; then
    echo "" >&2
    return
  fi

  # Remove 'v' prefix if present
  local target_clean=${target#v}

  # Parse version components
  local target_major target_minor target_patch
  IFS='.' read -r target_major target_minor target_patch <<< "$target_clean"

  # Special case: version 0.1.0 is the initial release
  if [[ "$target_major" == "0" ]] && [[ "$target_minor" == "1" ]] && [[ "$target_patch" == "0" ]]; then
    echo "" >&2
    return
  fi

  # Fetch all releases from GitHub
  local all_releases
  all_releases=$(gh release list --limit 100 --json tagName,isPrerelease --jq '.[] | select(.isPrerelease == false) | .tagName' 2>/dev/null || echo "")

  if [[ -z "$all_releases" ]]; then
    echo "" >&2
    return
  fi

  # Find the most recent release that is less than the target version
  local previous=""
  while IFS= read -r release; do
    if [[ -z "$release" ]]; then
      continue
    fi

    # Remove 'v' prefix
    local rel_clean=${release#v}

    # Parse release version components
    local rel_major rel_minor rel_patch
    IFS='.' read -r rel_major rel_minor rel_patch <<< "$rel_clean"

    # Compare versions: find the highest version that is less than target
    # For major version bumps (e.g., 2.0.0), find the latest from previous major (e.g., 1.x.x)
    # For minor version bumps (e.g., 0.2.0), find the latest from previous minor (e.g., 0.1.x)

    if [[ "$target_major" -gt "$rel_major" ]]; then
      # Target is a major version bump: find latest from previous major
      if [[ -z "$previous" ]]; then
        previous="$release"
      else
        local prev_clean=${previous#v}
        local prev_major prev_minor prev_patch
        IFS='.' read -r prev_major prev_minor prev_patch <<< "$prev_clean"

        # Update if this release is newer within the same major version
        if [[ "$rel_major" == "$prev_major" ]] && [[ "$rel_clean" > "$prev_clean" ]]; then
          previous="$release"
        elif [[ "$rel_major" -gt "$prev_major" ]]; then
          previous="$release"
        fi
      fi
    elif [[ "$target_major" == "$rel_major" ]] && [[ "$target_minor" -gt "$rel_minor" ]]; then
      # Same major, target has higher minor: find latest from previous minor
      if [[ -z "$previous" ]]; then
        previous="$release"
      else
        local prev_clean=${previous#v}
        local prev_major prev_minor prev_patch
        IFS='.' read -r prev_major prev_minor prev_patch <<< "$prev_clean"

        # Update if this release is newer within the same major version
        if [[ "$rel_major" == "$prev_major" ]] && [[ "$rel_clean" > "$prev_clean" ]]; then
          previous="$release"
        fi
      fi
    elif [[ "$target_major" == "$rel_major" ]] && [[ "$target_minor" == "$rel_minor" ]] && [[ "$target_patch" -gt "$rel_patch" ]]; then
      # Same major and minor, target has higher patch: find latest from previous patch
      if [[ -z "$previous" ]]; then
        previous="$release"
      else
        local prev_clean=${previous#v}
        local prev_major prev_minor prev_patch
        IFS='.' read -r prev_major prev_minor prev_patch <<< "$prev_clean"

        # Update if this release is newer
        if [[ "$rel_clean" > "$prev_clean" ]]; then
          previous="$release"
        fi
      fi
    fi
  done <<< "$all_releases"

  echo "$previous"
}

# Find all RC versions for the target version
find_rc_versions() {
  local target=$1
  if ! command -v ocm &> /dev/null; then
    echo "[]"
    return
  fi

  # Query OCM for all versions matching the RC pattern
  ocm get componentversions github.com/platform-mesh/platform-mesh \
    --repo ghcr.io/platform-mesh -o json 2>/dev/null | \
    jq -r ".items[] | select(.component.version | startswith(\"${target}-rc\")) | .component.version" | \
    sort -V || echo ""
}

# Fetch component versions from a specific OCM component version
fetch_component_refs() {
  local ocm_version=$1
  if ! command -v ocm &> /dev/null; then
    echo "{}"
    return
  fi

  local result
  result=$(ocm get component "github.com/platform-mesh/platform-mesh:${ocm_version}" \
    --repo ghcr.io/platform-mesh -o yaml 2>/dev/null)

  if [[ -z "$result" ]] || [[ "$result" == *"Error"* ]]; then
    echo "{}"
    return
  fi

  echo "$result" | yq eval '.component.componentReferences[] | {(.name): .version}' -o=json 2>/dev/null | \
    jq -s 'add // {}' 2>/dev/null || echo "{}"
}

# Fetch third-party versions from workflow YAML
fetch_third_party_versions() {
  local workflow_file=".github/workflows/ocm.yaml"

  if [[ ! -f "$workflow_file" ]]; then
    echo "{}"
    return
  fi

  # Extract env vars from the workflow and convert to JSON
  yq eval '.jobs.ocm.env' "$workflow_file" -o=json 2>/dev/null || echo "{}"
}

# Fetch latest release version from GitHub for a component
fetch_github_latest_version() {
  local org=$1
  local repo=$2

  if ! command -v gh &> /dev/null; then
    echo ""
    return
  fi

  # Fetch the latest release version
  gh api "repos/${org}/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null || echo ""
}

# Main execution
echo "=== Fetching Component Versions ===" >&2
echo "From version: $FROM_VERSION" >&2
echo "To version: $TO_VERSION" >&2
echo >&2

# Check if this is an initial release (from 0.0.0)
IS_INITIAL_RELEASE=false
if [[ "$FROM_VERSION" == "0.0.0" ]]; then
  IS_INITIAL_RELEASE=true
  echo "Initial release detected (from 0.0.0)" >&2
fi

# Initialize output JSON
jq -n \
  --arg from_version "$FROM_VERSION" \
  --arg to_version "$TO_VERSION" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    from_version: $from_version,
    to_version: $to_version,
    timestamp: $timestamp,
    current_release_components: {},
    previous_release_components: {},
    third_party: {},
    previous_third_party: {}
  }' > "$OUTPUT_FILE"

# Fetch "TO" version components
echo "Fetching component versions for $TO_VERSION..." >&2
to_components=$(fetch_component_refs "$TO_VERSION")

# If empty, try with 'v' prefix
if [[ "$to_components" == "{}" ]]; then
  echo "  Trying with 'v' prefix..." >&2
  to_components=$(fetch_component_refs "v${TO_VERSION}")
fi

# If still empty, try latest RC
if [[ "$to_components" == "{}" ]]; then
  echo "  Version not found in OCM registry" >&2
  echo "  Looking for latest release candidate..." >&2

  RC_VERSIONS=$(find_rc_versions "$TO_VERSION")

  if [[ -n "$RC_VERSIONS" ]]; then
    latest_rc=$(echo "$RC_VERSIONS" | tail -1)

    if [[ -n "$latest_rc" ]]; then
      echo "  Found latest RC: $latest_rc" >&2
      to_components=$(fetch_component_refs "$latest_rc")

      if [[ "$to_components" != "{}" ]]; then
        component_count=$(echo "$to_components" | jq 'keys | length' 2>/dev/null || echo "0")
        echo "  Found $component_count component(s) from latest RC" >&2
      fi
    fi
  else
    echo "  No release candidates found" >&2
  fi
fi

if [[ "$to_components" != "{}" ]]; then
  jq \
    --argjson curr "$to_components" \
    '.current_release_components = $curr' \
    "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
  mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

  component_count=$(echo "$to_components" | jq 'keys | length' 2>/dev/null || echo "0")
  echo "  Found $component_count component(s) for $TO_VERSION" >&2
fi

# Fetch third-party versions (current)
echo "  Fetching current third-party component versions..." >&2
third_party=$(fetch_third_party_versions)

jq \
  --argjson tp "$third_party" \
  '.third_party = $tp' \
  "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# Fetch "FROM" version components (skip if 0.0.0)
if [[ "$FROM_VERSION" != "0.0.0" ]]; then
  echo >&2
  echo "Fetching component versions for $FROM_VERSION..." >&2

  from_components=$(fetch_component_refs "$FROM_VERSION")

  # If empty, try with 'v' prefix
  if [[ "$from_components" == "{}" ]] && [[ "$FROM_VERSION" != v* ]]; then
    from_components=$(fetch_component_refs "v${FROM_VERSION}")
  fi

  jq \
    --argjson prev "$from_components" \
    '.previous_release_components = $prev' \
    "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
  mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

  # Try to fetch previous third-party versions from git
  if git rev-parse --verify "refs/tags/${FROM_VERSION}" >/dev/null 2>&1 || \
     git rev-parse --verify "refs/tags/v${FROM_VERSION}" >/dev/null 2>&1; then

    prev_tag="$FROM_VERSION"
    if ! git rev-parse --verify "refs/tags/${prev_tag}" >/dev/null 2>&1; then
      prev_tag="v${FROM_VERSION}"
    fi

    echo "  Fetching previous third-party versions from git tag $prev_tag..." >&2

    prev_third_party=$(git show "${prev_tag}:.github/workflows/ocm.yaml" 2>/dev/null | \
      yq eval '.jobs.ocm.env' - -o=json 2>/dev/null || echo "{}")

    jq \
      --argjson prev_tp "$prev_third_party" \
      '.previous_third_party = $prev_tp' \
      "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
  fi
fi

echo >&2
echo "Component versions saved to: $OUTPUT_FILE" >&2
echo >&2

# Output the JSON to stdout as well
cat "$OUTPUT_FILE"
