#!/bin/bash
#
# Bump a Helm chart's `version` based on the semver delta between its current
# `appVersion` and a new appVersion provided as input.
#
# Usage: bump-chart-version.sh <chart_file> <new_app_version>
#
# Mapping:
#   appVersion major  -> chart major  ( (M+1).0.0 )
#   appVersion minor  -> chart minor  ( M.(m+1).0 )
#   appVersion patch  -> chart patch  ( M.m.(p+1) )
#
# Exit codes:
#   0  chart updated, OR appVersion unchanged (no-op)
#   1  invalid input, downgrade refused, or malformed existing versions
#
# On stdout the script prints `NEW_CHART_VERSION` on the first line of the
# trailing "result" block so callers can grep it. Diagnostic messages go to
# stderr (or use `::error::` prefix when run under GitHub Actions).
set -euo pipefail

usage() {
  echo "Usage: $0 <chart_file> <new_app_version>" >&2
  exit 1
}

[ "$#" -eq 2 ] || usage
CHART_FILE="$1"
NEW_APP_VERSION="$2"

if [ ! -f "$CHART_FILE" ]; then
  echo "::error::Chart.yaml file not found at $CHART_FILE" >&2
  exit 1
fi

if ! [[ "$NEW_APP_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
  echo "::error::Invalid appVersion format: $NEW_APP_VERSION" >&2
  exit 1
fi

OLD_APP_VERSION=$(yq '.appVersion' "$CHART_FILE" | tr -d '"')

# Strip leading "v" and any pre-release/build suffix to compare clean MAJOR.MINOR.PATCH triplets.
strip() { local v="${1#v}"; printf '%s' "${v%%[-+]*}"; }
OLD_CLEAN=$(strip "$OLD_APP_VERSION")
NEW_CLEAN=$(strip "$NEW_APP_VERSION")

if ! [[ "$OLD_CLEAN" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Existing appVersion ($OLD_APP_VERSION) is not a clean semver triplet" >&2
  exit 1
fi

IFS='.' read -r OLD_MAJOR OLD_MINOR OLD_PATCH <<<"$OLD_CLEAN"
IFS='.' read -r NEW_MAJOR NEW_MINOR NEW_PATCH <<<"$NEW_CLEAN"

if [ "$OLD_CLEAN" = "$NEW_CLEAN" ]; then
  echo "appVersion unchanged ($OLD_APP_VERSION); nothing to do"
  exit 0
fi

if [ "$NEW_MAJOR" -lt "$OLD_MAJOR" ] \
  || { [ "$NEW_MAJOR" -eq "$OLD_MAJOR" ] && [ "$NEW_MINOR" -lt "$OLD_MINOR" ]; } \
  || { [ "$NEW_MAJOR" -eq "$OLD_MAJOR" ] && [ "$NEW_MINOR" -eq "$OLD_MINOR" ] && [ "$NEW_PATCH" -lt "$OLD_PATCH" ]; }; then
  echo "::error::appVersion downgrade refused: $OLD_APP_VERSION -> $NEW_APP_VERSION" >&2
  exit 1
fi

if   [ "$NEW_MAJOR" -gt "$OLD_MAJOR" ]; then BUMP=major
elif [ "$NEW_MINOR" -gt "$OLD_MINOR" ]; then BUMP=minor
else                                         BUMP=patch
fi

CHART_VERSION=$(yq '.version' "$CHART_FILE")
if ! [[ "$CHART_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Existing chart version ($CHART_VERSION) is not a clean semver triplet" >&2
  exit 1
fi
IFS='.' read -r CM Cm Cp <<<"$CHART_VERSION"
case "$BUMP" in
  major) NEW_CHART_VERSION="$((CM + 1)).0.0" ;;
  minor) NEW_CHART_VERSION="$CM.$((Cm + 1)).0" ;;
  patch) NEW_CHART_VERSION="$CM.$Cm.$((Cp + 1))" ;;
esac

yq e -i ".appVersion = \"${NEW_APP_VERSION}\"" "$CHART_FILE"
yq e -i ".version    = \"${NEW_CHART_VERSION}\"" "$CHART_FILE"

echo "Detected appVersion bump: $OLD_APP_VERSION -> $NEW_APP_VERSION ($BUMP)"
echo "Updated $CHART_FILE: version $CHART_VERSION -> $NEW_CHART_VERSION, appVersion $OLD_APP_VERSION -> $NEW_APP_VERSION"
