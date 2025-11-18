# Platform Mesh - Local Development Setup

For this setup we create a functional local platform-mesh environment using Kind (Kubernetes in Docker).
Is leverages Flux and Kustomize to manage the cluster and deploy Platform Mesh components.

## Prerequisites

### Required Dependencies

- **Container Runtime**: Either [Docker](https://www.docker.com) or [Podman](https://podman.io)
  - Docker Desktop is recommended for WSL2 users
  - Ensure the container daemon is running before starting setup
- **Kind**: [Kubernetes in Docker](https://kind.sigs.k8s.io/) for local Kubernetes clusters. [Installation](https://kind.sigs.k8s.io/docs/user/quick-start/)
- **Helm**: Required for bootstrapping Flux and managing Helm releases. [Installation](https://helm.sh/docs/intro/install/)
- **kubectl**: Kubernetes command-line tool (usually installed with Docker Desktop or Kind)
- **Task**: Task runner for executing project tasks. [Installation](https://taskfile.dev/installation/)
- **mkcert**: For generating local SSL certificates. [Installation](https://github.com/FiloSottile/mkcert?tab=readme-ov-file#installation)
  

### WSL2 + Windows mkcert Setup Guide

**Important for WSL2 users**: You need to set up mkcert to work across both WSL2 and Windows for proper certificate trust.

1. **Install mkcert in WSL2** (follow Linux instructions above)
2. **Install mkcert on Windows** using Chocolatey or download from releases
3. **Share CA between WSL2 and Windows**:
   ```sh
   # In WSL2, after installing mkcert:
   mkcert -install
   
   # Copy the CA to Windows (adjust path as needed):
   cp "$(mkcert -CAROOT)/rootCA.pem" /mnt/c/Users/$USER/mkcert-rootCA.pem
   ```
4. **Install CA in Windows**:
   ```powershell
   # In PowerShell as Administrator:
   Import-Certificate -FilePath "C:\Users\$env:USERNAME\mkcert-rootCA.pem" -CertStoreLocation Cert:\LocalMachine\Root
   ```

### Additional Tools (Automatically Checked)
The setup script will verify these additional dependencies:
- `yq` - YAML processor
- `base64` - Base64 encoding/decoding
- `openssl` - SSL certificate generation

### WSL2 Specific Requirements

If you're using Windows Subsystem for Linux (WSL2):
- WSL version 2.1.5 or higher is required
- Docker Desktop with WSL2 integration enabled
- Update WSL if needed: `wsl --update`

### Podman Specific Requirements for MacOS

If you're using Podman on MacOS make sure to set the following env:
```sh
KIND_EXPERIMENTAL_PROVIDER=podman <your-setup-command>
```

## Quick Start

### 1. Bootstrap Local Environment

The setup script automates the entire bootstrap process:
```sh
# Full setup (deletes existing cluster and creates new one)
task local-setup
```

You can also iterate on an existing cluster (faster, preserves cluster state):

```sh
# Iterate on existing cluster (faster, preserves cluster)
task local-setup:iterate
```

### 2. Alternative, Bootstrap Local Environment with image caching

#### One time activities to start local image registries:
```sh
task local-setup-start-docker-registries
```

#### Setup script to bootstrap the environment with locally cached images (faster initial setup):
```sh
task local-setup-cached
```

#### Iterate on existing cluster (faster, preserves cluster)
```sh
task local-setup-cached:iterate
```

#### Developer information
See [README-developers](./README-developers.md) for more detailed information related to chart developers.

### 3. Access the Platform

Once the setup completes successfully, you can access:

- **Onboarding Portal**: https://portal.dev.local:8443
- **Default Organization**: https://default.portal.dev.local:8443
- **KCP API**: https://kcp.api.portal.dev.local:8443

### 4. Configure Local DNS

Add the following entries to your `/etc/hosts` file:

```
127.0.0.1 default.portal.dev.local portal.dev.local kcp.api.portal.dev.local
```

**WSL Users**: You may also need to add these entries to the Windows hosts file at:
`C:\Windows\System32\drivers\etc\hosts`

## What the Setup Script Does

The `scripts/start.sh` script performs the following operations:

1. **Environment Validation**
   - Checks for required dependencies (Docker/Podman, Kind, kubectl, etc.)
   - Validates WSL2 compatibility if applicable
   - Verifies system architecture support
   - For Podman on macos: Verify that the KIND_EXPERIMENTAL_PROVIDER envs is set to `podman`

2. **Cluster Management**
   - Creates Kind cluster named `platform-mesh` (if not exists)
   - Uses Kubernetes v1.33.1 (`kindest/node:v1.33.1`)
   - Configures cluster with custom networking for local development

3. **Certificate Generation**
   - Generates local SSL certificates using mkcert
   - Creates CA certificates for webhook configurations
   - Sets up domain certificates for `*.dev.local` and `*.portal.dev.local`

4. **Core Infrastructure Installation**
   - Installs Flux for GitOps workflow management
   - Deploys Cert-Manager for SSL certificate management
   - Sets up OCM (Open Component Model) controller

5. **Platform Mesh Deployment**
   - Applies base Kustomize configurations
   - Creates necessary secrets (Keycloak, Grafana, certificates)
   - Deploys Platform Mesh operator and components
   - Installs supporting services (Keycloak, RBAC webhook, etc.)

6. **Post-Installation Setup**
   - Creates KCP admin kubeconfig for workspace access
   - Waits for all components to become ready
   - Provides access instructions and next steps

## Advanced Usage

### Working with KCP Workspaces

After successful setup, export the KCP kubeconfig to interact with workspaces:

```sh
export KUBECONFIG=$(pwd)/.secret/kcp/admin.kubeconfig
```

This gives you access to the root workspace and organization management.

### Adding New Organizations

Each onboarded organization requires its own subdomain entry in `/etc/hosts`:

```
127.0.0.1 <organization-name>.portal.dev.local
```

**⚠️ Important**: Remember to add hosts entries for every organization that gets onboarded to the platform.

### Debugging and Troubleshooting

#### Enable Debug Mode
```sh
DEBUG=true task local-setup:iterate
```

#### Check Component Status
```sh
# Check all Helm releases
kubectl get helmreleases -A

# Check Platform Mesh resource
kubectl get platformmesh -n platform-mesh-system

# Check pod status
kubectl get pods -A
```

#### Clean Start
The local-setup task will recreate the kind cluster from scratch
```sh
# Delete cluster and start fresh
task local-setup
```

### Development Workflow


## Files and Scripts

### Main Scripts
- `scripts/start.sh`: Main bootstrap script
- `scripts/check-environment.sh`: Dependency validation
- `scripts/check-wsl-compatibility.sh`: WSL2 compatibility checks
- `scripts/gen-certs.sh`: SSL certificate generation
- `scripts/createKcpAdminKubeconfig.sh`: KCP workspace access setup

### Configuration
- `kind/kind-config.yaml`: Kind cluster configuration
- `kind/kind-config-cached.yaml`: Kind cluster configuration with cached images
- `kustomize/`: Kubernetes manifests and overlays
- `webhook-config/`: Authorization webhook certificates and configuration

## Troubleshooting

### Common Issues

1. **Docker/Podman not running**
   - Ensure Docker Desktop or Podman is started
   - For WSL2: Verify Docker Desktop WSL integration is enabled

2. **Port conflicts**
   - Ensure ports 8443, 80, and 443 are not in use by other applications
   - Stop conflicting services before running setup

3. **Certificate issues**
   - Run `mkcert -install` to install the local CA
   - Check that mkcert is properly installed and accessible
   - **WSL2 users**: Certificate trust issues require setup in both WSL2 and Windows:
     ```sh
     # In WSL2: Install CA in Linux certificate store
     mkcert -install
     
     # Copy CA to Windows and install there too
     cp "$(mkcert -CAROOT)/rootCA.pem" /mnt/c/Users/$USER/mkcert-rootCA.pem
     ```
     Then in Windows PowerShell as Administrator:
     ```powershell
     Import-Certificate -FilePath "C:\Users\$env:USERNAME\mkcert-rootCA.pem" -CertStoreLocation Cert:\LocalMachine\Root
     ```
   - **Native Windows users**: If mkcert doesn't work properly, manually trust the CA:
     1. The CA certificate is generated at `local-setup/scripts/certs/ca.crt`
     2. Double-click the `ca.crt` file to open it
     3. Click "Install Certificate..."
     4. Select "Local Machine" and click "Next"
     5. Select "Place all certificates in the following store"
     6. Click "Browse..." and select "Trusted Root Certification Authorities"
     7. Click "Next" and then "Finish"
     8. Alternatively, use PowerShell as Administrator:
        ```powershell
        Import-Certificate -FilePath "local-setup\scripts\certs\ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
        ```
   - **Linux users**: After installing mkcert, ensure CA is trusted:
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
   - For WSL2: Also check Windows hosts file
   - Clear DNS cache if needed

5. **Cluster creation failures**
   - Check available disk space (need ~10GB)
   - Verify container runtime has sufficient resources
   - Try deleting other clusters that may be running and consuming resources
   - Try deleting existing cluster: `kind delete cluster --name platform-mesh`

6. **Component timeout issues**
   - Increase timeout values if you have a slower system
   - Trigger a new run using the `:iterate` tasks
   - Check component logs: `kubectl logs -n <namespace> <pod-name>`
   - Verify all required images can be pulled

### Getting Help

If you encounter issues:

1. Check the script output for specific error messages
2. Enable debug mode: `DEBUG=true task local-setup:iterate`
3. Verify all prerequisites are properly installed
4. Check cluster and component status using kubectl commands
5. Review logs of failing components

## Next Steps

After successful setup:

1. **Explore the Portal**: Visit https://portal.dev.local:8443
2. **Set up Organizations**: Create and configure organizations for your use case
3. **Development**: Start building on top of the Platform Mesh framework

For more detailed information about Platform Mesh concepts and usage, refer to the main project documentation.
