# Platform Mesh - Developer Setup

This directory bootstraps a full, self-contained Platform Mesh environment on your
local machine using [Kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker). It
leverages Flux/ArgoCD and Kustomize to manage the cluster and deploy Platform Mesh
components — everything runs on your laptop, no external cluster required.

It is meant for **local evaluation and contributor development**. For deploying
Platform Mesh onto a real Kubernetes cluster, use the production
[Installation guide](../installation/README.md) instead.

## Two modes

The Developer setup runs in one of two modes, selected by whether you build the OCM
aggregate locally:

| | **Pinned mode** (default) | **Local-build mode** (`--local-build`) |
|---|---|---|
| What it deploys | A **pre-built, published** OCM aggregate from `ghcr.io/platform-mesh` | An aggregate **built from your working tree** |
| Local component build | No | Yes (via an in-cluster OCI registry) |
| Speed / resources | Fast, light — "works out of the box" | Slower, resource-heavy |
| Who it's for | Evaluating Platform Mesh locally | Contributors testing local chart changes |
| Command | `task dev-setup` | `task dev-setup -- --local-build` |

If you are not sure, use **pinned mode** — it is the default and requires no extra flags.

## System Requirements

### Required

- **Container Runtime**: [Docker](https://www.docker.com) or [Podman](https://podman.io).
  Ensure the daemon is running before you start. (Docker Desktop is recommended for WSL2 users.)
- **Resources**: at least **12 GB of RAM** and ~10 GB free disk available to your
  container runtime. On Docker Desktop / Podman machine, raise the VM memory limit if
  needed — a machine capped below 12 GB is the most common cause of pods getting
  OOM-killed mid-setup. Local-build mode (`--local-build`) needs noticeably more.
- **Kind**: [Kubernetes in Docker](https://kind.sigs.k8s.io/) for local clusters. [Install](https://kind.sigs.k8s.io/docs/user/quick-start/)
- **Helm**: for bootstrapping Flux and managing releases. [Install](https://helm.sh/docs/intro/install/)
- **kubectl**: Kubernetes CLI (usually installed with Docker Desktop or Kind)
- **openssl**: for SSL certificate generation (typically pre-installed on Linux/macOS)
- **base64**: standard Unix utility, typically pre-installed
- **mkcert**: for local SSL certificates. [Install](https://github.com/FiloSottile/mkcert?tab=readme-ov-file#installation)
- **jq**: for parsing JSON from OCM CLI commands. [Install](https://jqlang.org/download/)
- **yq**: for processing YAML files. [Install](https://github.com/mikefarah/yq#install)

### Situational

- **kubectl-kcp plugin**: required only for the `--example-data` setup (kcp workspace management). [Install](https://docs.kcp.io/kcp/main/setup/kubectl-plugin/)
- **Node.js and npm**: required only to run the [E2E tests](#running-e2e-tests).

### Optional

- **Task**: task runner providing convenient aliases (e.g. `task dev-setup`). [Install](https://taskfile.dev/installation/)
  Not required — you can run the scripts directly (see examples below).

> Running on WSL2, native Windows, or macOS with Podman? See
> [Platform-specific setup](#platform-specific-setup) at the end of this document.

## Quick Start

The setup script automates the entire bootstrap. By default it pulls a pre-built,
published OCM component from `ghcr.io/platform-mesh` (pinned mode) — no local build required.

**Using Task (recommended):**

```sh
task dev-setup
```

**Without Task (direct script execution):**

```sh
./development/scripts/start.sh
```

The first run creates a fresh cluster. Subsequent runs reuse it (`--iterate=true` is
the default, so this is fast). To force a truly fresh cluster, delete the existing one
first and pass `--iterate=false`:

```sh
kind delete cluster --name platform-mesh
task dev-setup -- --iterate=false
```

### With Example Data (demo setup)

Includes an example provider ("httpbin") to showcase how provider integrations work —
useful for demonstrations and learning. Requires the
[kcp kubectl plugin](https://docs.kcp.io/kcp/main/setup/kubectl-plugin/).

```sh
task dev-setup -- --example-data
# or: ./development/scripts/start.sh --example-data
```

This creates a standard installation plus a `root:providers:httpbin-provider`
workspace with an HTTPBin provider configuration.

### Access the Platform

Once setup completes:

- **Onboarding Portal**: <https://portal.localhost:8443>
- **kcp API**: <https://localhost:8443>

Modern browsers automatically resolve `*.localhost` (including org subdomains like
`myorg.portal.localhost`) to `127.0.0.1`, so no `/etc/hosts` configuration is needed
for browser access.

If you installed with example data, explore the HTTPBin provider with the kcp admin
kubeconfig:

```sh
export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
```

## Commands and Options

All behavior is controlled by flags passed to `start.sh` after `--`, e.g.
`task dev-setup -- --local-build --example-data --concurrent --sharded=false`.
The task is `dev-setup` (the old name `local-setup` still works as an alias). For the
full flag list, run `./development/scripts/start.sh --help`.

### Version selection (pinned vs local-build)

**Pinned mode (default) — published components.** `task dev-setup` pulls a pre-built,
published OCM aggregate and deploys it. No local build, no in-cluster registry.

```sh
# Pull the default pinned version (recommended)
task dev-setup

# Pull a specific published version instead
PLATFORM_MESH_VERSION=0.4.0-build.510 task dev-setup
```

The default version is a hardcoded constant (`DEFAULT_PLATFORM_MESH_VERSION`) in
`development/scripts/start.sh`; override it with the `PLATFORM_MESH_VERSION`
environment variable to pin a different published version.

**Local-build mode (`--local-build`).** Builds the OCM aggregate from your working
tree and deploys it via an in-cluster OCI registry. This is **resource-heavy** and
slower, intended for contributors testing local chart changes — not for evaluation.

```sh
task dev-setup -- --local-build
```

`--local-build` is mutually exclusive with `PLATFORM_MESH_VERSION` (one builds from
source, the other pulls a published version) and is not supported with `--remote`.

### Common flags

- **`--iterate=BOOL`** (default `true`): reuse an existing cluster and only rebuild/reapply
  the OCM component — the fastest feedback loop. If no cluster exists yet, it falls
  through to a full setup automatically. Iterate only rebuilds from the working tree, so
  it is meaningful in local-build mode (`--local-build`). Pass `--iterate=false` to require a full
  setup; if a cluster already exists, `start.sh` fails and asks you to delete it first
  rather than guessing whether to reuse or replace it.
- **`--concurrent`**: build charts in parallel instead of sequentially (faster on multi-core systems).
- **`--sharded=BOOL`** (default `true`): deploy additional kcp shards alongside the root shard
  to test multi-shard topologies. Pass `--sharded=false` for a single-shard setup.
- **`--example-data`**: also deploy the HTTPBin example provider (requires the kubectl-kcp plugin).

### Remote (two-cluster) mode

With `--remote`, the setup creates two kind clusters instead of one:
`platform-mesh-infra` (where Flux/ArgoCD and the platform-mesh-operator run) and
`platform-mesh` (the runtime cluster where workloads, kcp and OCM resources land). The
operator routes HelmReleases/Applications to the infra cluster and OCM Resources to the
runtime cluster — a faithful local replica of a production split-cluster topology.

`--deployment-tech=fluxcd|argocd` (default `fluxcd`) selects the deployment technology.
With `argocd`, ArgoCD is installed on the infra cluster, the runtime cluster is
registered as a managed cluster, and each platform service becomes a separate ArgoCD
`Application` ordered through `argocd.argoproj.io/sync-wave`.

```sh
# FluxCD on a two-cluster topology
task dev-setup -- --remote --deployment-tech=fluxcd

# ArgoCD on a two-cluster topology
task dev-setup -- --remote --deployment-tech=argocd

# With example provider data (httpbin); requires the kubectl-kcp plugin
task dev-setup -- --remote --deployment-tech=fluxcd --example-data
```

## What the Setup Script Does

The `scripts/start.sh` script performs the following:

1. **Environment validation** — checks required dependencies (Docker/Podman, Kind,
   kubectl, etc.), validates WSL2 compatibility, verifies architecture. For Podman on
   macOS, verifies `KIND_EXPERIMENTAL_PROVIDER=podman`.
2. **Cluster management** — creates the Kind cluster `platform-mesh` (if not present)
   on Kubernetes v1.35.1 (`kindest/node:v1.35.1`) with custom local-dev networking.
3. **Certificate generation** — generates local SSL certificates with mkcert, CA certs
   for webhook configs, and domain certs for `localhost`, `*.localhost`, `*.portal.localhost`.
4. **Core infrastructure** — installs Flux, Cert-Manager, the OCM controller,
   CloudNativePG (CNPG), and the Keycloak Operator.
5. **Platform Mesh deployment** — applies base Kustomize configs, creates secrets,
   deploys the operator and components, provisions the shared PostgreSQL cluster,
   deploys Keycloak (via CR) and Dex (local upstream OIDC — see
   [upstream-identity-provider-dex.md](docs/upstream-identity-provider-dex.md)), and
   installs supporting services (RBAC webhook, observability, etc.).
6. **Post-installation** — creates the kcp admin kubeconfig, waits for readiness, and
   prints access instructions.
7. **Example data** (with `--example-data`) — creates the `root:providers` and
   `root:providers:httpbin-provider` workspaces and deploys the HTTPBin provider config.

## Contributor Workflow (local-build mode)

This section is for chart developers who want to test changes locally without going
through the official release process. It builds on the
[local-build mode](#version-selection-pinned-vs-local-build)
described above.

### Fresh setup with local charts

`--local-build` builds the OCM aggregate locally from the working tree:

```sh
task dev-setup -- --local-build

# With concurrent chart builds (faster on multi-core systems)
task dev-setup -- --local-build --concurrent
```

`--iterate=true` (the default) reuses an existing `platform-mesh` cluster and only
rebuilds/reapplies the OCM component — no cluster deletion or recreation. If no cluster
exists yet, this falls through to a full setup automatically:

1. Creates a fresh kind cluster
2. Deploys OCM infrastructure (OCI registry, transfer pod)
3. Builds your local chart changes into an OCM component
4. Deploys Platform Mesh using that component

To force a full setup even when a cluster already exists, delete it first and pass
`--iterate=false`:

```sh
kind delete cluster --name platform-mesh
task dev-setup -- --local-build --iterate=false
```

### Iterating on an existing cluster

With `--iterate=true` (the default), reusing an existing cluster:

- Skips cluster deletion and recreation
- Skips environment checks, certificate generation, and Flux installation
- Skips all OCM infrastructure setup (OCI registry, transfer pod)
- Only rebuilds the OCM component from local charts and reapplies it
- Reconfigures the transfer pod CA trust if certificates changed

This is the recommended approach for iterative development.

### Iterating on chart changes

After making chart changes on an already-running setup, rebuild and redeploy:

```sh
task ocm:build ocm:apply
```

This builds a new OCM component with your changes and applies it to the cluster.

### Starting from an existing pinned-mode setup

If you have a setup running in pinned mode and want to switch to a locally built component:

```sh
task ocm:deploy           # Deploy OCM infrastructure (once)
task ocm:build ocm:apply  # Build and deploy component
```

### Configuration (optional)

Edit `Taskfile.yaml` to configure:

- `COMPONENT_PRERELEASE_VERSION`: version for the component
- `CUSTOM_LOCAL_COMPONENTS_CHART_PATHS`: maps component names to local chart paths
- `COMPONENT_VERSION_FIX_DEPEDENCY_VERSIONS`: override specific dependency versions

### Cleanup

```sh
task ocm:cleanup       # Remove transfer pod and temp files
```

### Infrastructure architecture

The setup deploys the following key infrastructure components:

- **CloudNativePG (CNPG)**: manages a shared PostgreSQL cluster used by both Keycloak
  and OpenFGA. Replaces individual embedded PostgreSQL instances with a single
  operator-managed cluster that handles backups, failover, and database provisioning.
- **Keycloak Operator**: deploys Keycloak as a Custom Resource instead of a traditional
  Helm release. The operator manages the Keycloak lifecycle including upgrades and
  configuration reconciliation.
- **Observability stack**: OpenTelemetry collector for traces and metrics aggregation.

These components are declared as external components in the Platform Mesh profile
(`default-profile.yaml`) and are resolved during OCM component builds.

## Advanced Usage

### Working with kcp workspaces

After setup, export the kcp kubeconfig to interact with workspaces:

```sh
export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
```

This gives you access to the root workspace and organization management. Organization
subdomains like `<organization-name>.portal.localhost` are automatically resolved by
modern browsers — no `/etc/hosts` entries needed for browser access.

### Debugging

```sh
# Enable debug mode
DEBUG=true task dev-setup
# or: DEBUG=true ./development/scripts/start.sh

# Check component status
kubectl get helmreleases -A
kubectl get platformmesh -n platform-mesh-system
kubectl get pods -A
```

### Image registries

The kind cluster mounts `development/kind/containerd-certs.d/` into every node at
`/etc/containerd/certs.d` (see `kind-config.yaml`), so any registry configuration
placed there is automatically picked up by the cluster's containerd.

Three pull-through caches are configured and started automatically by
`setup-registry-proxies.sh`:

| Registry | Backed by |
|---|---|
| `ghcr.io` | `proxy-ghcr` container |
| `quay.io` | `proxy-quay` container |
| `registry.k8s.io` | `proxy-k8s-io` container |

**Custom local registries:** to make a local registry accessible to the cluster, add a
`hosts.toml` entry under `containerd-certs.d/<registry-host>/`. See the
[kind local registry documentation](https://kind.sigs.k8s.io/docs/user/local-registry/)
for the recommended setup pattern.

### Hook scripts

The setup provides four extension points (hook scripts) that run at different stages.
All are gitignored, so your local customizations won't be committed.

#### Load Custom Images hook

Runs after the Kind cluster is created, before Flux or any platform components are
installed. Use this to pre-load locally built images into the cluster's containerd
image store.

Create `development/scripts/load-custom-images.sh` — it is already gitignored:

```sh
#!/bin/bash
SCRIPT_DIR=$(dirname "$0")

# Example: replace the operator image with a locally built one instead of pulling from ghcr.io.
# The tag is read dynamically from the chart so it stays in sync with version bumps.
OPERATOR_TAG=$(grep '^appVersion:' "$SCRIPT_DIR/../../charts/platform-mesh-operator/Chart.yaml" | awk '{print $2}' | tr -d '"')
OPERATOR_IMAGE="ghcr.io/platform-mesh/platform-mesh-operator:${OPERATOR_TAG}"

echo "Injecting local operator image as ${OPERATOR_IMAGE}"
$CONTAINER_RUNTIME tag localhost:5001/platform-mesh-operator:latest "${OPERATOR_IMAGE}"
$CONTAINER_RUNTIME save "${OPERATOR_IMAGE}" | kind load image-archive /dev/stdin -n platform-mesh
$CONTAINER_RUNTIME rmi "${OPERATOR_IMAGE}"  # remove the temporary re-tag from the host
```

**Available at this point:** Kind cluster. Flux and all platform components are not yet installed.

**Notes:**

- `$CONTAINER_RUNTIME` is set by `start.sh` (`docker` or `podman`); use it instead of hardcoding either.
- `kind load image-archive /dev/stdin` works for both Docker and Podman (unlike `kind load docker-image`, which is Docker-only).
- Because the operator chart uses `imagePullPolicy: IfNotPresent`, containerd uses the pre-loaded image and skips the ghcr.io pull — provided the tag matches exactly what the OCM component references. The dynamic `appVersion` read above ensures this.

#### Post-Flux hook

Runs after Flux is installed and ready. Use this to load custom Docker images or deploy Flux resources.

```sh
cp development/scripts/post-flux-hook.sh.example development/scripts/post-flux-hook.sh
# Edit the script with your customizations
```

**Available at this point:** Kind cluster, TLS certificates, Flux (helm-controller, source-controller, kustomize-controller).

**Typical workflow:**

1. Build your local image: `docker build -t ghcr.io/platform-mesh/my-component:dev .`
2. Add the load command to `post-flux-hook.sh`
3. Run `task dev-setup` to reload the cluster with your custom images

#### Platform-Mesh Resource hook

Runs after the Platform-Mesh Operator is ready and the PlatformMesh CRD is established.
When this hook exists, it **replaces** the default PlatformMesh resource overlay logic —
the hook is responsible for applying the PlatformMesh resource to the cluster.

```sh
cp development/scripts/platform-mesh-resource-hook.sh.example development/scripts/platform-mesh-resource-hook.sh
# Edit the script with your customizations
```

**Available at this point:** everything from the post-flux hook, plus KRO, OCM,
Platform-Mesh Operator (ready), PlatformMesh CRD (established). Variables `$PRERELEASE`
and `$EXAMPLE_DATA` reflect the flags passed to start.sh.

```sh
# Apply a custom kustomize overlay for your PlatformMesh configuration
kubectl apply -k $SCRIPT_DIR/../kustomize/overlays/my-custom-overlay
```

#### Post-Platform-Mesh hook

Runs after the PlatformMesh resource is ready and kcp is accessible. Use this to create
kcp workspaces or deploy resources into the platform.

```sh
cp development/scripts/post-platform-mesh-hook.sh.example development/scripts/post-platform-mesh-hook.sh
# Edit the script with your customizations
```

**Available at this point:** everything from the post-flux hook, plus KRO, OCM,
Platform-Mesh Operator, PlatformMesh resource, and kcp admin kubeconfig (via `$KCP_KUBECONFIG`).

```sh
# Create a workspace in kcp
KUBECONFIG="$KCP_KUBECONFIG" kubectl create-workspace my-ws --type=root:providers --ignore-existing --server="https://localhost:8443/clusters/root"
```

## Running E2E Tests

After the setup is running, you can run end-to-end tests to verify portal functionality.

**Prerequisites:**

- Node.js and npm installed
- The setup cluster running (via `task dev-setup` or similar)
- `kubectl` available; `kubectl oidc-login` installed for the downloaded-kubeconfig smoke test
- `portal.localhost` must resolve locally for CLI tools (e.g. via `/etc/hosts`)
- Playwright browsers install automatically on first run

**Using Task:**

```sh
# Run the full developer-setup integration suite
task test:dev-setup

# Run CLI checks for backend resource readiness
task test:backend-resources

# Run tests in headless mode
task test:portal-e2e

# Run the HTTPBin flow
task test:portal-e2e:httpbins

# Run the marketplace UI flow (default availability + UI lifecycle check)
task test:portal-e2e:marketplace

# Run the account kubeconfig flow
task test:portal-e2e:account-kubeconfig

# Run the authorization flow
task test:portal-e2e:authorization

# Run the account deletion flow
task test:portal-e2e:deletion

# Run tests with visible browser window
task test:portal-e2e:headed

# Run tests more slowly to watch each browser action
SLOW_MO=500 task test:portal-e2e:headed

# Run tests with video recording (saved to development/e2e/test-results/)
task test:portal-e2e:video

# Specify organization name (default: "default")
ORG_NAME=myorg task test:portal-e2e
```

**Without Task:**

```sh
# Backend readiness checks
./development/scripts/check-backend-resources.sh

# Browser-driven portal checks
cd development/e2e
npm install
npm ci
npx playwright install
npx playwright test test-register-and-navigate.test.ts
```

**What the tests cover:**

- Portal onboarding and organization switching
- Inviting a second user and verifying unauthorized account access
- Account kubeconfig download plus a `kubectl` smoke test against the workspace
- Account deletion
- Namespace creation and HTTPBin creation in both `default` and `test`
- Opening the HTTPBin endpoint and verifying it responds
- Ready-condition checks for ContentConfigurations, Stores, IdentityProviderConfigurations, and WorkspaceTypes

## Files and Scripts

### Main scripts

- `scripts/start.sh`: main bootstrap script
- `scripts/check-environment.sh`: dependency validation
- `scripts/check-wsl-compatibility.sh`: WSL2 compatibility checks
- `scripts/gen-certs.sh`: SSL certificate generation
- `scripts/createKcpAdminKubeconfig.sh`: kcp workspace access setup
- `scripts/setup-prerelease.sh`: prerelease OCM component build and deployment
- `scripts/setup-registry-proxies.sh`: Docker registry mirror configuration
- `scripts/ocm-build-component.sh`: OCM component descriptor assembly
- `scripts/ocm-build-local-charts.sh`: local chart packaging for prerelease builds
- `scripts/check-backend-resources.sh`: post-setup resource readiness checks

### Configuration

- `kind/kind-config.yaml`: Kind cluster configuration
- `kustomize/`: Kubernetes manifests and overlays
- `webhook-config/`: authorization webhook certificates and configuration

## Troubleshooting

### Common issues

1. **Docker/Podman not running**
   - Ensure Docker Desktop or Podman is started
   - For WSL2: verify Docker Desktop WSL integration is enabled

2. **Port conflicts**
   - Ensure ports 8443, 80, and 443 are not in use by other applications
   - Stop conflicting services before running setup

3. **Certificate issues**
   - Run `mkcert -install` to install the local CA
   - Check that mkcert is properly installed and accessible
   - **WSL2 users**: certificate trust requires setup in both WSL2 and Windows — see
     [Platform-specific setup](#platform-specific-setup)
   - **Native Windows users**: if mkcert doesn't work properly, manually trust the CA:
     1. The CA certificate is generated at `development/scripts/certs/ca.crt`
     2. Double-click the `ca.crt` file to open it
     3. Click "Install Certificate..."
     4. Select "Local Machine" and click "Next"
     5. Select "Place all certificates in the following store"
     6. Click "Browse..." and select "Trusted Root Certification Authorities"
     7. Click "Next" and then "Finish"
     8. Alternatively, use PowerShell as Administrator:

        ```powershell
        Import-Certificate -FilePath "development\scripts\certs\ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
        ```

   - **Linux users**: after installing mkcert, ensure the CA is trusted:

     ```sh
     # Install the local CA in the system trust store
     mkcert -install

     # For Firefox users: manually import CA certificate
     # 1. Open Firefox → Settings → Privacy & Security → Certificates → View Certificates
     # 2. Go to "Authorities" tab → Import
     # 3. Navigate to $(mkcert -CAROOT) and select rootCA.pem
     # 4. Check "Trust this CA to identify websites"
     ```

4. **DNS resolution problems**
   - Verify `/etc/hosts` entries are correct
   - For WSL2: also check the Windows hosts file
   - Clear DNS cache if needed

5. **Cluster creation failures**
   - Check available disk space (need ~10 GB)
   - Verify the container runtime has **at least 12 GB of RAM** available (raise the
     Docker Desktop / Podman machine memory limit if needed) — an under-provisioned VM
     is the most common cause of failed or OOM-killed setups
   - Try deleting other running clusters consuming resources
   - Try deleting the existing cluster: `kind delete cluster --name platform-mesh`

6. **Component timeout issues**
   - Increase `KUBECTL_WAIT_TIMEOUT` if you have a slower system (default `1200s`)
   - Transfer-pod timeouts print pod details and Kubernetes events to help diagnose slow or failed image pulls
   - Trigger a new run with `task dev-setup` (iterate mode, the default)
   - Check component logs: `kubectl logs -n <namespace> <pod-name>`
   - Verify all required images can be pulled

7. **Helm credentials issues**
   - Make sure the Helm config file doesn't create authentication for `ghcr.io`
   - `helm registry logout ghcr.io`
   - `docker logout ghcr.io`

### Getting help

1. Check the script output for specific error messages
2. Enable debug mode: `DEBUG=true task dev-setup`
3. Verify all prerequisites are properly installed
4. Check cluster and component status using kubectl commands
5. Review logs of failing components

## Next Steps

After successful setup:

1. **Explore the Portal**: visit <https://portal.localhost:8443>
2. **Set up organizations**: create and configure organizations for your use case
3. **Development**: start building on top of the Platform Mesh framework

For more detailed information about Platform Mesh concepts and usage, refer to the main
project documentation.

## Platform-specific setup

These notes are only relevant if you run on WSL2, native Windows, or macOS with Podman.
Most Linux and macOS/Docker users can ignore this section.

### WSL2 + Windows mkcert setup

**Important for WSL2 users:** you need mkcert to work across both WSL2 and Windows for
proper certificate trust.

1. **Install mkcert in WSL2** (follow the Linux instructions above)
2. **Install mkcert on Windows** using Chocolatey or download from releases
3. **Share the CA between WSL2 and Windows**:

   ```sh
   # In WSL2, after installing mkcert:
   mkcert -install

   # Copy the CA to Windows (adjust path as needed):
   cp "$(mkcert -CAROOT)/rootCA.pem" /mnt/c/Users/$USER/mkcert-rootCA.pem
   ```

4. **Install the CA in Windows**:

   ```powershell
   # In PowerShell as Administrator:
   Import-Certificate -FilePath "C:\Users\$env:USERNAME\mkcert-rootCA.pem" -CertStoreLocation Cert:\LocalMachine\Root
   ```

### WSL2 specific requirements

If you're using Windows Subsystem for Linux (WSL2):

- WSL version 2.1.5 or higher is required
- Docker Desktop with WSL2 integration enabled
- Update WSL if needed: `wsl --update`

If Kubernetes is crashing because of a conflict between Cgroup v1 and v2 (a "hybrid"
state), you can force WSL2 to use **Cgroup v2 exclusively** (Unified Mode). This is the
modern standard starting from **Kubernetes v1.25**, where Cgroup v2 graduated to GA.

- Open PowerShell on Windows.
- Edit your `.wslconfig` file: `notepad $env:USERPROFILE\.wslconfig`
- Add these lines:

```text
[wsl2]
# Disable Cgroup V1 to force the kernel into "unified" (v2 only) mode
kernelCommandLine = cgroup_no_v1=all
```

### Podman on macOS

If you're using Podman on macOS, make sure to set the following env:

```sh
KIND_EXPERIMENTAL_PROVIDER=podman <your-setup-command>
```

### macOS Virtualization Framework (recommended)

For optimal performance and stability, we recommend Apple's Virtualization Framework
(VZ) with your container runtime:

**Docker Desktop:**

1. Open Docker Desktop
2. Go to Settings → General
3. Enable "Use Virtualization framework" or "VirtioFS"
4. Restart Docker Desktop

**Podman:**

1. Stop the current machine: `podman machine stop`
2. Remove the current machine: `podman machine rm`
3. Create a new machine with VZ: `podman machine init --vm-type=applehv`
4. Start the machine: `podman machine start`

While Platform Mesh can work with other virtualization frameworks like QEMU, it has been
primarily tested with Apple's Virtualization Framework on macOS.
