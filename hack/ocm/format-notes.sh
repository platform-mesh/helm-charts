#!/usr/bin/env bash
set -euo pipefail

# Script to format release notes in Markdown
# Usage: ./format-notes.sh <target-version> <versions-file> <changelog-file> <output-file>

TARGET_VERSION="${1:-}"
VERSIONS_FILE="${2:-generated/component-versions.json}"
CHANGELOG_FILE="${3:-generated/changelog.json}"
OUTPUT_FILE="${4:-dist/release-notes.md}"

if [[ -z "$TARGET_VERSION" ]]; then
  echo "Error: Target version required" >&2
  echo "Usage: $0 <target-version> [versions-file] [changelog-file] [output-file]" >&2
  exit 1
fi

if [[ ! -f "$VERSIONS_FILE" ]]; then
  echo "Error: Versions file not found: $VERSIONS_FILE" >&2
  exit 1
fi

if [[ ! -f "$CHANGELOG_FILE" ]]; then
  echo "Error: Changelog file not found: $CHANGELOG_FILE" >&2
  exit 1
fi

# Clean up dist directory and recreate it
rm -rf dist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Helper function to create markdown links
github_release_link() {
  local org=$1
  local repo=$2
  local version=$3
  echo "https://github.com/${org}/${repo}/releases/tag/${version}"
}

github_compare_link() {
  local org=$1
  local repo=$2
  local old_ver=$3
  local new_ver=$4
  echo "https://github.com/${org}/${repo}/compare/${old_ver}...${new_ver}"
}

# Format the release notes
format_release_notes() {
  local version=$1
  local versions_file=$2
  local changelog_file=$3

  # Get RC info
  local rc_versions=$(jq -r '.release_candidates[].version' "$versions_file" | tr '\n' ' ' | sed 's/ $//')
  local rc_count=$(jq -r '.release_candidates | length' "$versions_file")

  # Get change counts
  local change_count=$(jq -r '.changes | length' "$changelog_file")
  local breaking_count=$(jq -r '[.changes[] | select(.is_breaking)] | length' "$changelog_file")

  # Get final component versions (from last RC)
  local last_rc_idx=$((rc_count - 1))

  # Start generating markdown
  cat << EOF
# Platform Mesh OCM Component ${version}

EOF

  if [[ $rc_count -gt 0 ]]; then
    cat << EOF
This is the initial stable release of the Platform Mesh OCM component, aggregating changes from ${rc_count} release candidate(s): ${rc_versions}.

EOF
  else
    cat << EOF
This release of the Platform Mesh OCM component includes updates to multiple components.

EOF
  fi

  # Summary section
  if [[ $change_count -gt 0 ]]; then
    cat << EOF
## Summary

This release includes ${change_count} component update(s)$([ $breaking_count -gt 0 ] && echo ", including ${breaking_count} with breaking changes 🔥" || echo "").

EOF
  fi

  # Contributors section
  cat << 'EOF'
## Contributors

Thank you to all the contributors who made this release possible:

EOF

  # Collect unique contributors from all PRs across all components
  local contributors=$(jq -r '[.changes[].pr_details[]? | {author: .author, author_url: .author_url, avatar_url: .avatar_url}] | unique_by(.author) | sort_by(.author)' "$changelog_file")
  local contributor_count=$(echo "$contributors" | jq 'length')

  if [[ "$contributor_count" -gt 0 ]]; then
    # Render contributors with avatars in a compact format
    echo "<div>"
    echo ""
    while IFS= read -r contributor; do
      if [[ -n "$contributor" ]] && [[ "$contributor" != "null" ]]; then
        local author=$(echo "$contributor" | jq -r '.author // ""')
        local author_url=$(echo "$contributor" | jq -r '.author_url // ""')
        local avatar_url=$(echo "$contributor" | jq -r '.avatar_url // ""')

        if [[ -n "$author" ]] && [[ -n "$author_url" ]] && [[ -n "$avatar_url" ]]; then
          echo "<a href=\"${author_url}\"><img src=\"${avatar_url}\" width=\"50\" height=\"50\" alt=\"${author}\" title=\"${author}\" style=\"border-radius: 50%; margin: 5px;\"></a>"
        fi
      fi
    done < <(echo "$contributors" | jq -c '.[]')
    echo ""
    echo "</div>"
    echo ""
    echo "_${contributor_count} contributor(s)_"
  else
    echo "_No contributors found_"
  fi
  echo ""

  # Component Changes section
  if [[ $change_count -gt 0 ]]; then
    cat << EOF
## Component Changes$([ $rc_count -gt 0 ] && echo " Across Release Candidates" || echo "")

### Platform Mesh Components

EOF

    # Iterate through changes
    local changes=$(jq -c '.changes[]' "$changelog_file")
    while IFS= read -r change; do
      local component=$(echo "$change" | jq -r '.component')
      local old_ver=$(echo "$change" | jq -r '.old_version')
      local new_ver=$(echo "$change" | jq -r '.new_version')
      local is_breaking=$(echo "$change" | jq -r '.is_breaking')
      local release_notes=$(echo "$change" | jq -r '.release_notes.body // ""')
      local release_url=$(echo "$change" | jq -r '.release_notes.html_url // ""')

      # Extract OCM component details
      local chart_ref=$(echo "$change" | jq -r '.ocm_details.resources[]? | select(.type == "helmChart") | .access.imageReference // ""')
      local chart_version=$(echo "$change" | jq -r '.ocm_details.resources[]? | select(.type == "helmChart") | .version // ""')
      local image_ref=$(echo "$change" | jq -r '.ocm_details.resources[]? | select(.type == "ociImage") | .access.imageReference // ""')
      local image_version=$(echo "$change" | jq -r '.ocm_details.resources[]? | select(.type == "ociImage") | .version // ""')
      local chart_source_repo=$(echo "$change" | jq -r '.ocm_details.sources[]? | select(.name == "chart") | .access.repoUrl // ""')
      local chart_source_commit=$(echo "$change" | jq -r '.ocm_details.sources[]? | select(.name == "chart") | .access.commit // ""')
      local image_source_repo=$(echo "$change" | jq -r '.ocm_details.sources[]? | select(.name == "source") | .access.repoUrl // ""')
      local image_source_version=$(echo "$change" | jq -r '.ocm_details.sources[]? | select(.name == "source") | .version // ""')
      local raw_yaml=$(echo "$change" | jq -r '.ocm_details.raw_yaml // ""')

      # Component header
      if [[ "$is_breaking" == "true" ]]; then
        echo "#### ${component}: ${old_ver} → ${new_ver} 🔥"
      else
        echo "#### ${component}: ${old_ver} → ${new_ver}"
      fi
      echo ""

      # Links section in table format
      echo "| Resource | Version | Links |"
      echo "|----------|---------|-------|"

      # Chart row
      if [[ -n "$chart_ref" ]]; then
        local chart_links="[Package](https://${chart_ref})"

        # Chart source link (if available, skip for private repos)
        if [[ -n "$chart_source_repo" ]] && [[ "$chart_source_repo" == https://github.com/* ]] && [[ "$chart_source_repo" != *"helm-charts-priv"* ]]; then
          chart_links="${chart_links} • [Source](${chart_source_repo}/tree/${chart_source_commit}/charts/${component})"
        fi

        echo "| 📦 Helm Chart | \`${chart_version}\` | ${chart_links} |"
      fi

      # Image row
      if [[ -n "$image_ref" ]]; then
        local image_links="[Package](https://${image_ref})"

        # Image source release link (if available, skip for components from private repos)
        if [[ -n "$image_source_repo" ]] && [[ -n "$image_source_version" ]]; then
          # Handle both github.com URLs and ghcr.io references
          local github_repo=""
          if [[ "$image_source_repo" == https://github.com/* ]]; then
            github_repo="$image_source_repo"
          elif [[ "$image_source_repo" == ghcr.io/* ]]; then
            # Convert ghcr.io/platform-mesh/component to github.com/platform-mesh/component
            github_repo="https://github.com/${image_source_repo#ghcr.io/}"
          fi

          # Link to release page (not tag), skip for private repos
          if [[ -n "$github_repo" ]] && [[ "$chart_source_repo" != *"helm-charts-priv"* ]]; then
            image_links="${image_links} • [Release](${github_repo}/releases/tag/${image_source_version})"
          fi
        fi

        echo "| 🐳 Container Image | \`${image_version}\` | ${image_links} |"
      fi

      # Add raw OCM YAML in collapsed section (if available)
      if [[ -n "$raw_yaml" ]] && [[ "$raw_yaml" != "null" ]]; then
        echo ""
        echo "<details>"
        echo "<summary>OCM Component Descriptor (click to expand)</summary>"
        echo ""
        echo '```yaml'
        echo "$raw_yaml"
        echo '```'
        echo ""
        echo "</details>"
      fi

      # Extract and display PR changelog items
      local pr_changelogs=$(echo "$change" | jq -r '.pr_changelogs[]? // empty' 2>/dev/null)

      if [[ -n "$pr_changelogs" ]]; then
        echo ""
        echo "**Key Changes:**"
        echo ""
        while IFS= read -r item; do
          if [[ -n "$item" ]]; then
            # Ensure item starts with a dash, add if missing
            if [[ "$item" == -* ]]; then
              echo "$item"
            else
              echo "- $item"
            fi
          fi
        done <<< "$pr_changelogs"
      fi

      # Extract and display PR details as collapsible list
      local pr_details=$(echo "$change" | jq -c '.pr_details[]? // empty' 2>/dev/null)

      if [[ -n "$pr_details" ]]; then
        local pr_count=$(echo "$change" | jq '.pr_details | length' 2>/dev/null || echo "0")
        echo ""
        echo "<details>"
        echo "<summary>All Pull Requests (${pr_count})</summary>"
        echo ""

        while IFS= read -r pr_json; do
          if [[ -n "$pr_json" ]]; then
            local pr_number=$(echo "$pr_json" | jq -r '.number // ""')
            local pr_title=$(echo "$pr_json" | jq -r '.title // ""')
            local pr_url=$(echo "$pr_json" | jq -r '.url // ""')
            local pr_author=$(echo "$pr_json" | jq -r '.author // ""')
            local pr_author_url=$(echo "$pr_json" | jq -r '.author_url // ""')

            if [[ -n "$pr_number" ]] && [[ -n "$pr_url" ]]; then
              if [[ -n "$pr_author" ]] && [[ -n "$pr_author_url" ]]; then
                echo "- [#${pr_number}](${pr_url}): ${pr_title} by [@${pr_author}](${pr_author_url})"
              else
                echo "- [#${pr_number}](${pr_url}): ${pr_title}"
              fi
            fi
          fi
        done <<< "$pr_details"

        echo ""
        echo "</details>"
      fi

      echo ""

    done <<< "$changes"
  fi

  # Third-party components section
  cat << EOF

### Third-Party Components

The following third-party components are included in this release:

EOF

  # Get third-party versions from workflow env
  local third_party=$(jq -r '.third_party' "$versions_file")

  # Map env var names to component names, GitHub repos, and tag format
  # Format: "Display Name|org/repo|tag_format"
  # tag_format: "v" = prepend v, "prefix-" = prepend prefix-, "openfga-" = openfga prefix, "kcp-operator-" = kcp-operator prefix, "" = as-is
  declare -A tp_map=(
    ["GATEWAY_API_VERSION"]="Gateway API|kubernetes-sigs/gateway-api|"
    ["TRAEFIK_VERSION"]="Traefik|traefik/traefik-helm-chart|v"
    ["CERT_MANAGER_VERSION"]="Cert Manager|cert-manager/cert-manager|"
    ["CROSSPLANE_VERSION"]="Crossplane|crossplane/crossplane|v"
    ["OPENFGA_VERSION"]="OpenFGA|openfga/helm-charts|openfga-"
    ["KCP_OPERATOR_VERSION"]="KCP Operator|kcp-dev/helm-charts|kcp-operator-"
    ["GARDENER_ETCD_DRUID_SOURCE_REF"]="etcd-druid|gardener/etcd-druid|"
  )

  for env_var in "${!tp_map[@]}"; do
    IFS='|' read -r display_name repo tag_format <<< "${tp_map[$env_var]}"
    local tp_version=$(echo "$third_party" | jq -r ".${env_var} // \"unknown\"")

    if [[ "$tp_version" != "unknown" ]] && [[ -n "$tp_version" ]]; then
      # Apply tag format
      if [[ -n "$tag_format" ]]; then
        tag="${tag_format}${tp_version}"
      else
        tag="$tp_version"
      fi

      release_url=$(github_release_link "${repo%%/*}" "${repo##*/}" "$tag")
      echo "- **${display_name}** ${tp_version} - [Release Notes](${release_url})"
    fi
  done

  # All component versions (collapsible)
  cat << EOF

## All Component Versions

<details>
<summary>Complete version manifest (click to expand)</summary>

| Component | Version |
|-----------|---------|
EOF

  # List all components from last RC or current release
  if [[ $rc_count -gt 0 ]]; then
    jq -r ".release_candidates[${last_rc_idx}].components | to_entries[] | \"| \\(.key) | \\(.value) |\"" "$versions_file"
  else
    jq -r ".current_release_components | to_entries[] | \"| \\(.key) | \\(.value) |\"" "$versions_file"
  fi

  cat << EOF

</details>

EOF

  # OCM Component Descriptor section
  # Determine which version to fetch (use to_version from versions file which is the RC version)
  local ocm_version=$(jq -r '.to_version' "$versions_file")

  # Fetch platform-mesh component descriptor
  local platform_mesh_yaml=""
  if command -v ocm &> /dev/null; then
    platform_mesh_yaml=$(ocm get component "github.com/platform-mesh/platform-mesh:${ocm_version}" --repo ghcr.io/platform-mesh -o yaml 2>/dev/null || echo "")
  fi

  if [[ -n "$platform_mesh_yaml" ]]; then
    cat << EOF
<details>
<summary>Platform Mesh OCM Component Descriptor (click to expand)</summary>

\`\`\`yaml
${platform_mesh_yaml}
\`\`\`

</details>

EOF
  fi

  cat << EOF
## Installation

For installation instructions, see the [Getting Started Guide](https://platform-mesh.io/main/getting-started).

To fetch the component using OCM CLI:

\`\`\`bash
ocm get component github.com/platform-mesh/platform-mesh:${version} --repo ghcr.io/platform-mesh
\`\`\`

---
*Generated with Claude Code*
EOF
}

# Main execution
echo "=== Formatting Release Notes ===" >&2
echo >&2

format_release_notes "$TARGET_VERSION" "$VERSIONS_FILE" "$CHANGELOG_FILE" > "$OUTPUT_FILE"

echo "✓ Release notes formatted and saved to: $OUTPUT_FILE" >&2
echo >&2
