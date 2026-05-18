#!/bin/bash
#
# Tests for hack/bump-chart-version.sh
#
# Run with: bash hack/bump-chart-version.test.sh
# Requires `yq` (mikefarah) on PATH.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/bump-chart-version.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "yq not found on PATH" >&2
  exit 1
fi

PASS=0
FAIL=0
FAIL_NAMES=()

make_chart() {
  # make_chart <dir> <version> <appVersion>
  cat >"$1/Chart.yaml" <<YAML
apiVersion: v2
name: test
version: $2
appVersion: "$3"
YAML
}

assert() {
  # assert <name> <expected_exit> <expected_chart_version_or_-> <expected_app_version_or_-> <output...>
  local name="$1" exp_exit="$2" exp_ver="$3" exp_app="$4"
  shift 4
  local actual_exit="$1" actual_ver="$2" actual_app="$3"
  if [ "$actual_exit" = "$exp_exit" ] \
     && { [ "$exp_ver" = "-" ] || [ "$actual_ver" = "$exp_ver" ]; } \
     && { [ "$exp_app" = "-" ] || [ "$actual_app" = "$exp_app" ]; }; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    echo "        expected: exit=$exp_exit version=$exp_ver appVersion=$exp_app"
    echo "        actual:   exit=$actual_exit version=$actual_ver appVersion=$actual_app"
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$name")
  fi
}

run_case() {
  # run_case <name> <chart_version> <old_app> <new_app> <expected_exit> <expected_chart_after> <expected_app_after>
  local name="$1" chart_ver="$2" old_app="$3" new_app="$4" exp_exit="$5" exp_ver="$6" exp_app="$7"
  local tmp; tmp=$(mktemp -d)
  make_chart "$tmp" "$chart_ver" "$old_app"
  bash "$SCRIPT" "$tmp/Chart.yaml" "$new_app" >/dev/null 2>&1
  local rc=$?
  local actual_ver actual_app
  actual_ver=$(yq '.version' "$tmp/Chart.yaml")
  actual_app=$(yq '.appVersion' "$tmp/Chart.yaml" | tr -d '"')
  assert "$name" "$exp_exit" "$exp_ver" "$exp_app" "$rc" "$actual_ver" "$actual_app"
  rm -rf "$tmp"
}

echo "Running bump-chart-version.sh tests..."

# Happy paths: each segment moves
run_case "patch bump"                      "0.39.3" "v1.11.3" "v1.11.4"      0 "0.39.4" "v1.11.4"
run_case "minor bump resets patch"         "0.39.3" "v1.11.3" "v1.12.0"      0 "0.40.0" "v1.12.0"
run_case "major bump resets minor+patch"   "0.39.3" "v1.11.3" "v2.0.0"       0 "1.0.0"  "v2.0.0"

# Pre-release suffix is stripped for comparison but written through unchanged.
run_case "pre-release counts toward minor" "0.39.3" "v1.11.3" "v1.12.0-rc.1" 0 "0.40.0" "v1.12.0-rc.1"

# No-op: file untouched.
run_case "unchanged is no-op"              "0.39.3" "v1.11.3" "v1.11.3"      0 "0.39.3" "v1.11.3"

# Downgrade: error, file untouched.
run_case "minor downgrade refused"         "0.39.3" "v1.11.3" "v1.10.9"      1 "0.39.3" "v1.11.3"
run_case "patch downgrade refused"         "0.39.3" "v1.11.3" "v1.11.2"      1 "0.39.3" "v1.11.3"
run_case "major downgrade refused"         "0.39.3" "v2.0.0"  "v1.99.99"     1 "0.39.3" "v2.0.0"

# Skipping segments still classifies as the highest moved segment.
run_case "minor skip (1.11 -> 1.13)"       "0.39.3" "v1.11.3" "v1.13.0"      0 "0.40.0" "v1.13.0"
run_case "major skip (1.x -> 3.0.0)"       "0.39.3" "v1.11.3" "v3.0.0"       0 "1.0.0"  "v3.0.0"

# appVersion without the leading "v" still works (some charts store it that way).
run_case "no-v prefix old, v-prefix new"   "0.39.3" "1.11.3"  "v1.12.0"      0 "0.40.0" "v1.12.0"

# Invalid new appVersion format -> error before mutation.
tmp=$(mktemp -d); make_chart "$tmp" "0.39.3" "v1.11.3"
bash "$SCRIPT" "$tmp/Chart.yaml" "not-a-version" >/dev/null 2>&1; rc=$?
actual_ver=$(yq '.version' "$tmp/Chart.yaml"); actual_app=$(yq '.appVersion' "$tmp/Chart.yaml" | tr -d '"')
assert "invalid new appVersion refused" 1 "0.39.3" "v1.11.3" "$rc" "$actual_ver" "$actual_app"
rm -rf "$tmp"

# Missing chart file -> error.
bash "$SCRIPT" "/nonexistent/Chart.yaml" "v1.0.0" >/dev/null 2>&1; rc=$?
assert "missing chart file errors" 1 "-" "-" "$rc" "-" "-"

# Wrong arg count -> error.
bash "$SCRIPT" "only-one-arg" >/dev/null 2>&1; rc=$?
assert "wrong arg count errors" 1 "-" "-" "$rc" "-" "-"

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  - %s\n' "${FAIL_NAMES[@]}"
  exit 1
fi
