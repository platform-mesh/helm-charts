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

# Fetch PRs merged between two versions
fetch_component_prs() {
  local org=$1
  local repo=$2
  local old_version=$3
  local new_version=$4

  echo "      Looking for commits between ${old_version} and ${new_version}..." >&2

  # Skip if old version is empty (initial component addition)
  if [[ -z "$old_version" ]]; then
    echo "      No previous version (initial component addition)" >&2
    echo "[]"
    return
  fi

  # Get commit SHAs for both versions (try with and without 'v' prefix)
  local old_sha new_sha
  echo "      Fetching commit SHA for tag ${old_version}..." >&2

  # Try without 'v' prefix first
  old_sha=$(gh api "repos/${org}/${repo}/git/ref/tags/${old_version}" 2>/dev/null | jq -r '.object.sha // empty' 2>/dev/null)
  if [[ -z "$old_sha" ]]; then
    # Try with 'v' prefix
    old_sha=$(gh api "repos/${org}/${repo}/git/ref/tags/v${old_version}" 2>/dev/null | jq -r '.object.sha // empty' 2>/dev/null)
  fi

  echo "      Fetching commit SHA for tag ${new_version}..." >&2

  # Try without 'v' prefix first
  new_sha=$(gh api "repos/${org}/${repo}/git/ref/tags/${new_version}" 2>/dev/null | jq -r '.object.sha // empty' 2>/dev/null)
  if [[ -z "$new_sha" ]]; then
    # Try with 'v' prefix
    new_sha=$(gh api "repos/${org}/${repo}/git/ref/tags/v${new_version}" 2>/dev/null | jq -r '.object.sha // empty' 2>/dev/null)
  fi

  # Return empty array if we can't find the commits
  if [[ -z "$old_sha" ]] || [[ -z "$new_sha" ]]; then
    echo "      Could not find commit SHAs for version tags" >&2
    echo "        Old version (${old_version}): ${old_sha:-(not found)}" >&2
    echo "        New version (${new_version}): ${new_sha:-(not found)}" >&2
    echo "[]"
    return
  fi

  echo "      Found SHAs - Old: ${old_sha:0:7}, New: ${new_sha:0:7}" >&2
  echo "      Comparing commits ${old_sha:0:7}...${new_sha:0:7}" >&2

  # Fetch comparison between versions
  local comparison
  comparison=$(gh api "repos/${org}/${repo}/compare/${old_sha}...${new_sha}" 2>/dev/null || echo "")

  if [[ -z "$comparison" ]]; then
    echo "      No commits found in comparison" >&2
    echo "[]"
    return
  fi

  local commit_count=$(echo "$comparison" | jq -r '.commits | length' 2>/dev/null || echo "0")
  echo "      Found ${commit_count} commit(s) in range" >&2

  # Extract PR numbers from commit messages (GitHub's merge commits include PR numbers)
  local pr_numbers
  pr_numbers=$(echo "$comparison" | jq -r '.commits[]?.commit.message' 2>/dev/null | \
    grep -oP '(?<=#)\d+(?=\))' | sort -u | jq -R . | jq -s . || echo "[]")

  local pr_count=$(echo "$pr_numbers" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$pr_count" -gt 0 ]]; then
    echo "      Extracted ${pr_count} unique PR number(s) from commit messages" >&2
  else
    echo "      No PR numbers found in commit messages" >&2
  fi

  echo "$pr_numbers"
}

# Fetch PR info (details + changelog) in a single API call
# Returns JSON object: {pr_details: [{number, title, url}], pr_changelogs: ["item1", "item2"]}
fetch_pr_info_and_changelog() {
  local org=$1
  local repo=$2
  local pr_numbers_json=$3  # JSON array like [123, 456]

  local pr_details="[]"
  local pr_changelogs="[]"

  echo "      Fetching PR details and changelogs..." >&2

  while IFS= read -r pr_num; do
    if [[ -z "$pr_num" ]] || [[ "$pr_num" == "null" ]]; then
      continue
    fi

    echo "        PR #${pr_num}: Fetching..." >&2

    # Fetch PR details from GitHub API (single call gets everything)
    local pr_data
    if ! pr_data=$(gh api "repos/${org}/${repo}/pulls/${pr_num}" 2>&1); then
      echo "        PR #${pr_num}: Not found or failed to fetch" >&2
      continue
    fi

    # Validate JSON before using it
    if ! echo "$pr_data" | jq empty 2>/dev/null; then
      echo "        PR #${pr_num}: Invalid JSON response" >&2
      continue
    fi

    if [[ "$pr_data" == "{}" ]] || [[ "$pr_data" == "null" ]]; then
      echo "        PR #${pr_num}: Empty response" >&2
      continue
    fi

    # Extract PR metadata (number, title, URL, author)
    local pr_info=$(echo "$pr_data" | jq '{
      number: .number,
      title: .title,
      url: .html_url,
      author: .user.login,
      author_url: .user.html_url,
      avatar_url: .user.avatar_url
    }' 2>/dev/null || echo "{}")

    if [[ "$pr_info" != "{}" ]] && [[ "$pr_info" != "null" ]]; then
      pr_details=$(jq -n --argjson existing "$pr_details" --argjson new "$pr_info" '$existing + [$new]')
    fi

    # Extract changelog from PR body
    local pr_body=$(echo "$pr_data" | jq -r '.body // ""')

    if [[ -n "$pr_body" ]] && [[ "$pr_body" != "null" ]]; then
      # Extract content under "# Change Log", "## Change Log", or "### Change Log" section
      local changelog_content
      changelog_content=$(echo "$pr_body" | awk '
        BEGIN { in_changelog=0; }
        /^#{1,3}[[:space:]]+Change[[:space:]]+Log/ { in_changelog=1; next; }
        /^#/ { if (in_changelog) exit; }
        { if (in_changelog && length($0) > 0) print; }
      ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

      if [[ -n "$changelog_content" ]]; then
        # Extract bullet points and convert to JSON array
        local changelog_items
        changelog_items=$(echo "$changelog_content" | grep -E '^[-*+][[:space:]]' | \
          sed 's/^[-*+][[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//' | \
          jq -R . | jq -s . || echo "[]")

        if [[ "$changelog_items" != "[]" ]]; then
          local item_count=$(echo "$changelog_items" | jq 'length' 2>/dev/null || echo "0")
          echo "        PR #${pr_num}: Found $item_count changelog item(s)" >&2
          pr_changelogs=$(jq -n --argjson existing "$pr_changelogs" --argjson new "$changelog_items" '$existing + $new')
        else
          echo "        PR #${pr_num}: No changelog entries" >&2
        fi
      else
        echo "        PR #${pr_num}: No changelog section" >&2
      fi
    fi

  done < <(echo "$pr_numbers_json" | jq -r '.[]' 2>/dev/null)

  # Return both pr_details and pr_changelogs as a JSON object
  jq -n \
    --argjson details "$pr_details" \
    --argjson changelogs "$pr_changelogs" \
    '{pr_details: $details, pr_changelogs: $changelogs}'
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

  # Combine into single JSON object
  jq -n \
    --argjson resources "$resources" \
    --argjson sources "$sources" \
    '{resources: $resources, sources: $sources}' 2>/dev/null || echo "{}"
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

  # Fetch OCM component details for BOTH old and new versions
  old_ocm_details=$(fetch_ocm_component_details "$component" "$first_ver")
  if [[ -z "$old_ocm_details" ]] || ! echo "$old_ocm_details" | jq empty 2>/dev/null; then
    old_ocm_details="{}"
  fi

  new_ocm_details=$(fetch_ocm_component_details "$component" "$last_ver")
  if [[ -z "$new_ocm_details" ]] || ! echo "$new_ocm_details" | jq empty 2>/dev/null; then
    new_ocm_details="{}"
  fi

  # Fetch PR changelogs from image repository only
  echo "    Fetching PRs and changelogs..." >&2

  # Extract image details from OLD OCM component
  old_image_version=$(echo "$old_ocm_details" | jq -r '.resources[]? | select(.type == "ociImage") | .version // empty')
  old_image_source_repo=$(echo "$old_ocm_details" | jq -r '.sources[]? | select(.name == "source") | .access.repoUrl // empty')

  # Extract image details from NEW OCM component
  new_image_version=$(echo "$new_ocm_details" | jq -r '.resources[]? | select(.type == "ociImage") | .version // empty')
  new_image_source_repo=$(echo "$new_ocm_details" | jq -r '.sources[]? | select(.name == "source") | .access.repoUrl // empty')

  # Initialize PR list and track repo info
  pr_numbers="[]"
  image_repo_org=""
  image_repo_name=""

  # Only fetch PRs if we have both old and new image versions AND they differ
  if [[ -n "$old_image_version" ]] && [[ -n "$new_image_version" ]] && [[ "$old_image_version" != "$new_image_version" ]]; then

    # Extract org/repo from image source repository
    if [[ "$new_image_source_repo" == https://github.com/* ]]; then
      image_repo_org=$(echo "$new_image_source_repo" | sed 's|https://github.com/||' | cut -d'/' -f1)
      image_repo_name=$(echo "$new_image_source_repo" | sed 's|https://github.com/||' | cut -d'/' -f2)
    elif [[ "$new_image_source_repo" == ghcr.io/* ]]; then
      # Assume GitHub repo matches ghcr.io path
      image_repo_org=$(echo "$new_image_source_repo" | sed 's|ghcr.io/||' | cut -d'/' -f1)
      image_repo_name=$(echo "$new_image_source_repo" | sed 's|ghcr.io/||' | cut -d'/' -f2)
    fi

    if [[ -n "$image_repo_org" ]] && [[ -n "$image_repo_name" ]]; then
      echo "    Image version changed: ${old_image_version} → ${new_image_version}" >&2
      echo "    Fetching PRs from image repository (${image_repo_org}/${image_repo_name})..." >&2

      pr_numbers=$(fetch_component_prs "$image_repo_org" "$image_repo_name" "$old_image_version" "$new_image_version")
    fi
  else
    echo "    Skipping PR fetch - no image version change detected" >&2
    if [[ -z "$old_image_version" ]]; then
      echo "      Old image version: (not found)" >&2
    fi
    if [[ -z "$new_image_version" ]]; then
      echo "      New image version: (not found)" >&2
    fi
    if [[ -n "$old_image_version" ]] && [[ -n "$new_image_version" ]] && [[ "$old_image_version" == "$new_image_version" ]]; then
      echo "      Image versions are identical: $old_image_version" >&2
    fi
  fi

  # Fetch PR info (details + changelog) in a single pass
  pr_details="[]"
  pr_changelogs="[]"

  if [[ "$pr_numbers" != "[]" ]] && [[ -n "$pr_numbers" ]] && [[ -n "$image_repo_org" ]] && [[ -n "$image_repo_name" ]]; then
    pr_count=$(echo "$pr_numbers" | jq 'length' 2>/dev/null || echo "0")
    echo "    Found $pr_count unique PR(s) from image repository: $(echo "$pr_numbers" | jq -r 'join(", ")' 2>/dev/null || echo "$pr_numbers")" >&2

    # Fetch everything in one pass
    pr_info=$(fetch_pr_info_and_changelog "$image_repo_org" "$image_repo_name" "$pr_numbers")

    # Extract pr_details and pr_changelogs from result
    pr_details=$(echo "$pr_info" | jq '.pr_details')
    pr_changelogs=$(echo "$pr_info" | jq '.pr_changelogs')

    pr_details_count=$(echo "$pr_details" | jq 'length' 2>/dev/null || echo "0")
    changelog_count=$(echo "$pr_changelogs" | jq 'length' 2>/dev/null || echo "0")
    echo "    Fetched $pr_details_count PR(s) with $changelog_count total changelog item(s)" >&2
  else
    echo "    No PRs found for this version range" >&2
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
    --argjson ocm "$new_ocm_details" \
    --argjson pr_changelogs "$pr_changelogs" \
    --argjson pr_details "$pr_details" \
    '.changes += [{
      component: $comp,
      old_version: $old_ver,
      new_version: $new_ver,
      is_breaking: ($breaking == "true"),
      release_notes: $release,
      ocm_details: $ocm,
      pr_changelogs: $pr_changelogs,
      pr_details: $pr_details
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
echo "✓ Found $change_count component change(s)" >&2
echo "✓ Found $third_party_change_count third-party component change(s)" >&2
echo "✓ Changelog saved to: $OUTPUT_FILE" >&2
echo >&2
