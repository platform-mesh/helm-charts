# Developer documentation

This section is for chart developers who want to test changes locally without going through the official release process.

## Quick Start: Fresh Setup with Local Charts

By default, `task local-setup` builds the OCM aggregate locally from the working tree.

```sh
task local-setup

# With concurrent chart builds (faster on multi-core systems)
task local-setup -- --concurrent
```

`--iterate=true` is the default. If a `platform-mesh` kind cluster already exists, it's reused and only the OCM component is rebuilt/reapplied — no cluster deletion or recreation. If no cluster exists yet, this falls through to a full setup automatically:
1. Creates a fresh kind cluster
2. Deploys OCM infrastructure (OCI registry, transfer pod)
3. Builds your local chart changes into a OCM component
4. Deploys platform mesh using the component

To force a full setup even when a cluster already exists, delete it first and pass `--iterate=false`:

```sh
kind delete cluster --name platform-mesh
task local-setup -- --iterate=false
```

To deploy a *published* aggregate from `ghcr.io/platform-mesh` instead, set `PLATFORM_MESH_VERSION` (requires `--iterate=false` if a cluster already exists, since iterate mode only rebuilds from the working tree):

```sh
PLATFORM_MESH_VERSION=0.4.0-build.510 task local-setup
```

## Iterating on an Existing Cluster

With `--iterate=true` (the default), reusing an existing cluster:
- Skips cluster deletion and recreation
- Skips environment checks, certificate generation, and Flux installation
- Skips all OCM infrastructure setup (OCI registry, transfer pod)
- Only rebuilds the OCM component from local charts and reapplies it
- Reconfigures the transfer pod CA trust if certificates changed

This is the recommended approach for iterative development.

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
