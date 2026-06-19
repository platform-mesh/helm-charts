# Developer documentation

This section is for chart developers who want to test changes locally without going through the official release process.

## Quick Start: Fresh Setup with Local Charts

By default, `task local-setup` builds the OCM aggregate locally from the working tree.

```sh
# Full setup with locally built components (deletes existing cluster)
task local-setup

# With concurrent chart builds (faster on multi-core systems)
task local-setup:concurrent
```

This automatically:
1. Creates a fresh kind cluster
2. Deploys OCM infrastructure (OCI registry, transfer pod)
3. Builds your local chart changes into a OCM component
4. Deploys platform mesh using the component

To deploy a *published* aggregate from `ghcr.io/platform-mesh` instead, set `PLATFORM_MESH_VERSION`:

```sh
PLATFORM_MESH_VERSION=0.4.0-build.510 task local-setup
```

## Testing with an Existing Cluster

If you already have a running cluster and want to test changes without recreating it, use the `:iterate` variant:

```sh
# Reuse existing cluster (faster, no cluster recreation)
task local-setup:iterate

# With concurrent chart builds
task local-setup:concurrent:iterate
```

This is the recommended approach for iterative development as it:
- Skips cluster deletion and recreation
- Skips environment checks, certificate generation, and Flux installation
- Skips all OCM infrastructure setup (OCI registry, transfer pod)
- Only rebuilds the OCM component from local charts and reapplies it
- Reconfigures the transfer pod CA trust if certificates changed

The `--iterate` flag requires `PLATFORM_MESH_VERSION` to be unset (build-locally path) — it has no effect on published-version setups since there is nothing to rebuild.

## Iterating on Chart Changes

After making chart changes on an already running setup, rebuild and redeploy:

```sh
task ocm:build ocm:apply
```

This builds a new OCM component with your changes and applies it to the cluster.

## Configuration (Optional)

Edit `Taskfile.yaml` to configure:
- `COMPONENT_PRERELEASE_VERSION`: Version for the component
- `CUSTOM_LOCAL_COMPONENTS_CHART_PATHS`: Maps component names to local chart paths
- `COMPONENT_VERSION_FIX_DEPEDENCY_VERSIONS`: Override specific dependency versions

## Advanced: Starting from Existing Published Setup

If you have a running local-setup with published components (`PLATFORM_MESH_VERSION=...`) and want to switch to a locally built component:

```sh
task ocm:deploy           # Deploy OCM infrastructure (once)
task ocm:build ocm:apply  # Build and deploy component
```

## Cleanup

```sh
task ocm:cleanup       # Remove transfer pod and temp files
```

## Infrastructure Architecture

The local setup deploys the following key infrastructure components:

- **CloudNativePG (CNPG)**: Manages a shared PostgreSQL cluster used by both Keycloak and OpenFGA. Replaces individual embedded PostgreSQL instances with a single operator-managed cluster that handles backups, failover, and database provisioning.
- **Keycloak Operator**: Deploys Keycloak as a Custom Resource instead of a traditional Helm release. The operator manages the Keycloak lifecycle including upgrades and configuration reconciliation.
- **Observability stack**: OpenTelemetry collector for traces and metrics aggregation.

These components are declared as external components in the Platform Mesh profile (`default-profile.yaml`) and are resolved during OCM component builds.
