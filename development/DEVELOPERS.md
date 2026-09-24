# Developer documentation

This section is for chart developers who want to test changes locally without going through the official release process.

> For the full set of setup modes, flags, and prerequisites, see the [Developer setup README](README.md). This guide covers only the contributor workflow of building components locally. The default `task dev-setup` runs in PINNED mode (published components); building from your working tree is opt-in via `--build-local`.

## Quick Start: Fresh Setup with Local Charts

`--build-local` builds the OCM aggregate locally from the working tree.

```sh
task dev-setup -- --build-local

# With concurrent chart builds (faster on multi-core systems)
task dev-setup -- --build-local --concurrent
```

`--iterate=true` is the default. If a `platform-mesh` kind cluster already exists, it's reused and only the OCM component is rebuilt/reapplied — no cluster deletion or recreation. If no cluster exists yet, this falls through to a full setup automatically:
1. Creates a fresh kind cluster
2. Deploys OCM infrastructure (OCI registry, transfer pod)
3. Builds your local chart changes into a OCM component
4. Deploys platform mesh using the component

To force a full setup even when a cluster already exists, delete it first and pass `--iterate=false`:

```sh
kind delete cluster --name platform-mesh
task dev-setup -- --build-local --iterate=false
```

To deploy a *published* aggregate from `ghcr.io/platform-mesh` instead of building locally, omit `--build-local` (PINNED mode is the default). See the [README version options](README.md#understanding-version-options).

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

If you have a running Developer setup with published components (PINNED mode) and want to switch to a locally built component:

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
