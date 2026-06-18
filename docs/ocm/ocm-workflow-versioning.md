# OCM Workflow Versioning

This document describes the versioning behavior of the Platform Mesh OCM component build workflow.

## Overview

The OCM workflow (`ocm.yaml`) builds and publishes the Platform Mesh OCM component. It supports automatic versioning based on dependency changes, as well as manual version control through workflow dispatch inputs.

## Workflow Triggers

The workflow runs on:

- **Schedule**: Hourly (`0 * * * *`)
- **Push**: When changes are made to `ocm.yaml` or `component-constructor.yaml` on the `main` branch
- **Manual dispatch**: Via GitHub Actions UI with configurable inputs

## Workflow Inputs

When triggering the workflow manually, the following inputs are available:

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `force_version_upgrade` | boolean | `false` | Force version upgrade even without dependency changes |
| `version_increment` | choice | `minor` | Version component to increment |
| `release_type` | choice | `build` | Type of release to create |

### version_increment Options

| Option | Description |
|--------|-------------|
| `none` | Keep the base semantic version unchanged, only modify the release type suffix |
| `minor` | Increment the minor version (e.g., 0.2.0 → 0.3.0) |
| `major` | Increment the major version (e.g., 0.2.0 → 1.0.0) |
| `patch` | Increment the patch version (e.g., 0.2.0 → 0.2.1) |

### release_type Options

| Option | Description | Example |
|--------|-------------|---------|
| `build` | Development build with build number suffix | `0.2.0-build.1` |
| `rc` | Release candidate with rc number suffix | `0.2.0-rc.1` |
| `full` | Full release without any suffix | `0.2.0` |

## Version Calculation

### Automatic Versioning (Default Behavior)

When the workflow runs automatically (schedule or push), it:

1. Compares current dependency versions against the last published component
2. If dependencies changed, increments the build number of the current version
3. If no changes, skips component creation

Examples:
- `0.2.0-build.5` → `0.2.0-build.6` (dependency change detected)
- `0.2.0-rc.1` → `0.2.0-rc.2` (dependency change detected)

### Manual Versioning (force_version_upgrade: true)

When `force_version_upgrade` is enabled, the `version_increment` and `release_type` inputs control the new version:

#### Using version_increment: none

Use `none` when you want to change the release type without bumping the semantic version. This is useful for:

- Creating a release candidate from a build version
- Promoting a release candidate to a full release
- Resetting the build/rc counter

| Current Version | version_increment | release_type | Result |
|----------------|-------------------|--------------|--------|
| `0.2.0-build.716` | `none` | `rc` | `0.2.0-rc.1` |
| `0.2.0-build.716` | `none` | `full` | `0.2.0` |
| `0.2.0-build.716` | `none` | `build` | `0.2.0-build.1` |
| `0.2.0-rc.3` | `none` | `full` | `0.2.0` |
| `0.2.0-rc.3` | `none` | `build` | `0.2.0-build.1` |

#### Using version_increment: minor/major/patch

Use these options when you want to bump the semantic version:

| Current Version | version_increment | release_type | Result |
|----------------|-------------------|--------------|--------|
| `0.2.0-build.716` | `minor` | `build` | `0.3.0-build.1` |
| `0.2.0-build.716` | `minor` | `rc` | `0.3.0-rc.1` |
| `0.2.0-build.716` | `minor` | `full` | `0.3.0` |
| `0.2.0-build.716` | `major` | `rc` | `1.0.0-rc.1` |
| `0.2.0-build.716` | `patch` | `rc` | `0.2.1-rc.1` |

### Promoting Pre-releases to Full Releases

When the current version already has a pre-release suffix (`-build.X` or `-rc.X`) and `release_type: full` is selected, the workflow strips the suffix to create a full release:

| Current Version | version_increment | release_type | Result |
|----------------|-------------------|--------------|--------|
| `0.2.0-rc.1` | (any) | `full` | `0.2.0` |
| `0.2.0-build.5` | (any) | `full` | `0.2.0` |

## Common Use Cases

### Creating a Release Candidate

To create `0.2.0-rc.1` from `0.2.0-build.716`:

```
force_version_upgrade: true
version_increment: none
release_type: rc
```

### Promoting RC to Full Release

To create `0.2.0` from `0.2.0-rc.3`:

```
force_version_upgrade: true
version_increment: none
release_type: full
```

### Starting a New Minor Version

To create `0.3.0-build.1` from `0.2.0-build.716`:

```
force_version_upgrade: true
version_increment: minor
release_type: build
```

### Creating a New Major RC

To create `1.0.0-rc.1` from `0.2.0-build.716`:

```
force_version_upgrade: true
version_increment: major
release_type: rc
```
