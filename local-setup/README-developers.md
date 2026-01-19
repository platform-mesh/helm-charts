# Developer documentation

This section is for chart developers who want to test changes locally without going through the official release process.

## Quick Start: Fresh Setup with Local Charts

The simplest way to test local chart changes is using the `--prerelease` flag:

```sh
# Full setup with locally built components (deletes existing cluster)
task local-setup:prerelease

# With caching for faster image pulls
task local-setup:cached:prerelease
```

This automatically:
1. Creates a fresh kind cluster
2. Deploys OCM infrastructure (OCI registry, transfer pod)
3. Builds your local chart changes into a prerelease OCM component
4. Deploys platform mesh using the prerelease component

## Testing with an Existing Cluster

If you already have a running cluster and want to test prerelease changes without recreating it, use the `:iterate` variant:

```sh
# Reuse existing cluster (faster, no cluster recreation)
task local-setup:prerelease:iterate

# With caching
task local-setup:cached:prerelease:iterate
```

This is the recommended approach for iterative development as it:
- Skips cluster deletion and recreation
- Reuses existing OCM infrastructure
- Only rebuilds and redeploys the changed components

## Iterating on Chart Changes

After making chart changes on an already running prerelease setup, rebuild and redeploy:

```sh
task ocm:build ocm:apply
```

This builds a new prerelease OCM component with your changes and applies it to the cluster.

## Configuration (Optional)

Edit `Taskfile.yaml` to configure:
- `COMPONENT_PRERELEASE_VERSION`: Version for the prerelease component
- `CUSTOM_LOCAL_COMPONENTS_CHART_PATHS`: Maps component names to local chart paths
- `COMPONENT_VERSION_FIX_DEPEDENCY_VERSIONS`: Override specific dependency versions

## Advanced: Starting from Existing Released Setup

If you have a running local-setup with released components and want to switch to prerelease mode:

```sh
task ocm:deploy           # Deploy OCM infrastructure (once)
task ocm:build ocm:apply  # Build and deploy prerelease component
```

## Cleanup

```sh
task ocm:cleanup       # Remove transfer pod and temp files
```
