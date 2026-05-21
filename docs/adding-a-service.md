# Adding a New Service to PlatformMesh

This guide walks through the end-to-end process of adding a new service to the PlatformMesh platform. A "service" is any workload managed by the platform-mesh-operator — it can be a backend API, UI frontend, controller/operator, or infrastructure component.

## Overview

Adding a service touches multiple repositories and systems:

```text
┌─────────────────────┐     ┌──────────────────────┐     ┌───────────────────────────────────────┐
│  Service Image Repo │     │  helm-charts Repo    │     │  platform-mesh/ocm Repo               │
│                     │     │                      │     │                                       │
│  - Source code      │     │  - Helm chart        │     │  Service component workflow:          │
│  - Dockerfile       │     │  - GHA workflow      │     │    Combines chart + image into        │
│  - Image CI/CD      │     │  - OCM constructor   │     │    service OCM component              │
│                     │     │  - Profile config    │     │                                       │
│  Produces:          │     │                      │     │  Aggregator workflow:                 │
│  - OCI image        │────▶│  Produces:           │────▶│    Bumps service version in the       │
│  - image OCM comp.  │     │  - chart OCM comp.   │     │    platform-mesh component            │
│                     │     │  - triggers OCM wf   │     │                                       │
│                     │     │                      │     │  Produces:                            │
│                     │     │                      │     │  - service OCM comp. (chart + image)  │
│                     │     │                      │     │  - new platform-mesh component version│
└─────────────────────┘     └──────────────────────┘     └───────────────────────────────────────┘
```

**Key concept**: The helm-charts repo produces a chart-level OCM component and triggers OCM workflows in the `platform-mesh/ocm` repository. Those workflows combine the chart component with the image component into a service-level OCM component. A separate aggregator workflow in the same OCM repo then creates a new version of the platform-mesh component that includes the updated service. The platform-mesh-operator reconciles services declared in the PlatformMesh profile into FluxCD HelmReleases.

## Step 1: Create the Helm Chart

### Directory Structure

Create a new chart under `charts/<service-name>/`:

```text
charts/my-service/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deploy.yaml
│   ├── service.yaml
│   ├── sa.yaml
│   └── httproute.yaml    (if the service exposes an HTTP API)
└── tests/
    └── __snapshot__/
```

### Chart.yaml

Declare a dependency on the `common` library chart:

```yaml
apiVersion: v2
name: my-service
description: A Helm chart for my-service
version: 0.1.0
appVersion: v0.1.0
dependencies:
  - name: common
    version: 0.12.2
    repository: oci://ghcr.io/platform-mesh/helm-charts
```

- `version` is the chart version (bumped on chart changes)
- `appVersion` is the container image tag (bumped when a new image is released)
- If the service has no container image (chart-only, e.g. a UI bundle), set `appVersion: "0.0.0"`

### values.yaml

Use the structure expected by the `common` chart helpers:

```yaml
image:
  name: ghcr.io/platform-mesh/my-service
  pullPolicy: IfNotPresent

port: 8080

deployment:
  resources:
    limits:
      memory: "512Mi"
    requests:
      cpu: "40m"
      memory: "50Mi"
```

### Templates

Use helpers from the `common` chart in your templates:

- `{{ include "common.entity.name" . }}` — consistent naming
- `{{ include "common.image" . }}` — image reference with tag
- `{{ include "common.healthAndReadiness" . }}` — liveness/readiness probes
- `{{ include "common.deploymentBasics" . }}` — replicas, strategy, selectors
- `{{ include "common.resources" . }}` — resource limits/requests
- `{{ include "common.basicEnvironment" . }}` — standard env vars

See `charts/common/templates/` for the full list of available helpers.

### If Your Service Has CRDs

Create a separate CRD chart `charts/my-service-crds/` and reference it as a conditional dependency:

```yaml
# In charts/my-service/Chart.yaml
dependencies:
  - name: common
    version: 0.12.2
    repository: oci://ghcr.io/platform-mesh/helm-charts
  - name: my-service-crds
    version: 0.1.0
    repository: oci://ghcr.io/platform-mesh/helm-charts
    condition: crds.enabled
```

### Run Tests and Generate Docs

```sh
helm dependency update charts/my-service
helm unittest charts/my-service           # or: task helmtest-update
task docs                                  # regenerate README from values.yaml
```

## Step 2: Container Image

The container image is built in a separate repository (e.g., `platform-mesh/my-service`).

### Requirements

- Image must be published to `ghcr.io/platform-mesh/my-service`
- Tags must follow semver: `v0.1.0`, `v0.2.3`, etc.
- The image repo must use the reusable GitHub workflow from `platform-mesh/.github` that handles version propagation automatically

### Automated Version Propagation

The version linkage between image and chart is fully automated:

1. A new container image is released in the service image repo
2. The reusable workflow automatically updates `appVersion` and `version` in `charts/<service>/Chart.yaml` in this repo
3. The chart change on main triggers the chart workflow (`.github/workflows/<service>.yaml`)
4. The chart workflow builds the chart-level OCM component and triggers downstream OCM workflows that produce the service component and update the platform-mesh component

## Step 3: OCM Component Creation

Services are packaged as [Open Component Model](https://ocm.software/) components for distribution and deployment.

### Component Naming

Two naming patterns exist:

| Type | Component Name | When to Use |
| ---- | -------------- | ----------- |
| Chart-only | `github.com/platform-mesh/helm-charts/<name>` | Charts without a linked image (UI bundles, CRD charts) |
| Full service | `github.com/platform-mesh/<name>` | Charts with a container image — wraps chart + image sub-components |

### Component Constructor Files

Located in `.ocm/`:

**Default constructors** (used by most services):

- `.ocm/component-constructor-chart-only.yaml` — for chart-only components (no linked image)
- `.ocm/component-constructor.yaml` — for full service components (chart + image)

**Chart-only constructor** template:

```yaml
components:
  - name: {{ .COMPONENT_NAME }}
    version: {{ .VERSION }}
    provider:
      name: The Platform Mesh Team
    resources:
      - name: chart
        type: helmChart
        relation: external
        version: {{ .VERSION }}
        access:
          type: ociArtifact
          imageReference: "{{ .CHART_OCI_PATH }}:{{ .VERSION }}"
    sources:
      - name: chart
        type: git
        version: {{ .VERSION }}
        access:
          commit: {{ .COMMIT }}
          repoUrl: {{ .CHART_REPO }}
          type: gitHub
```

**Optional per-service overrides**: You can create a service-specific constructor file (e.g., `.ocm/component-constructor-my-service.yaml`) to override the default behavior. This is only needed when a service has special dependencies or a non-standard component structure. See `.ocm/component-constructor-example-httpbin-operator.yaml` as an example.

### Service-Level and Top-Level OCM Components

The chart-level OCM component is produced here in the helm-charts repo. However, the **service-level component** (combining chart + image) and the **top-level platform-mesh component** are created in the `platform-mesh/ocm` repository, which contains:

- Service component constructors (combining chart and image sub-components)
- The aggregator constructor (top-level platform-mesh component referencing all services)
- Workflows that trigger on chart or image component updates
- Configuration for version resolution and component signing

## Step 4: GitHub Workflows

### Chart Workflow (helm-charts repo)

Create `.github/workflows/my-service.yaml`:

```yaml
name: Build my-service Workflow
on:
  push:
    branches:
      - main
    paths:
      - 'charts/my-service/**'
      - '.github/workflows/my-service.yaml'
      - '.ocm/component-constructor-chart-only.yaml'

permissions:
  contents: write
  packages: write

jobs:
  pipeline:
    concurrency:
      group: my-service-${{ github.ref }}
      cancel-in-progress: true
    uses: ./.github/workflows/pipeline-chart.yml
    with:
      chartFolder: charts
      chartName: my-service
      componentConstructorFile: .ocm/component-constructor-chart-only.yaml
      chartOnly: true
    secrets: inherit
```

**Key inputs to `pipeline-chart.yml`:**

| Input | Description |
| ----- | ----------- |
| `chartOnly: true` | Builds chart component only; the image repo builds the full service component |
| `chartOnly: false` | Builds the full service component (chart + image) from this repo |
| `componentConstructorFile` | Which `.ocm/` template to use |
| `imageComponentName` | Override image component name (defaults to chart name) |
| `serviceComponentConstructorFile` | Custom constructor in the OCM repo |

### Image Workflow (service image repo)

The image repository needs a workflow that:

1. Builds and pushes the container image to `ghcr.io/platform-mesh/my-service`
2. Creates an OCM image component (`github.com/platform-mesh/images/my-service`)
3. Triggers the full service component build (`github.com/platform-mesh/my-service`) which references both chart and image

### PR Validation

PR checks run automatically via `.github/workflows/pr-checks.yml` when chart files are modified. This runs helm lint, unit tests, and documentation checks.

## Step 5: Profile / PlatformMesh Resource Configuration

Add your service to the default profile ConfigMap at:
`local-setup/kustomize/components/platform-mesh-operator-resource/default-profile.yaml`

### Service Declaration

Add under `components.services`:

```yaml
my-service:
  imageResources:
    - annotations:
        repo: oci
        artifact: image
        for: my-service
  syncWave: 4
  enabled: true
  values:
    # Service-specific Helm values overrides
    hostAliases:
      enabled: true
```

### Configuration Fields

| Field | Description |
| ----- | ----------- |
| `enabled` | Enable/disable the service |
| `syncWave` | Deployment order (1=first, 4=last). Use lower waves for dependencies |
| `imageResources` | OCM image resources to track for image tag injection |
| `values` | Helm values overrides passed to the chart |
| `external` | `true` if the component lives outside this repo's OCM hierarchy |
| `helmRepo` | `true` if deployed from an external Helm repository (not OCM) |
| `targetNamespace` | Override the deployment namespace |
| `dependsOn` | List of services that must be ready before this one deploys |
| `absoluteReferencePath` | Path within the OCM component tree to find this service's chart |
| `suspend` | `true` to create the HelmRelease in suspended state (unsuspended by the operator when image resources are processed) |

### Deployment Ordering

The ordering mechanism depends on the deployment technology:

**ArgoCD**: Uses `syncWave` to control deployment order. Lower waves deploy first:

- **Wave 1**: Infrastructure operators (kcp-operator, cert-manager)
- **Wave 2**: Core platform (platform-mesh-operator)
- **Wave 3**: Supporting infra (infra chart with Keycloak, CNPG, networking)
- **Wave 4**: Application services (iam-service, portal, your service)

**FluxCD**: Uses a suspend/unsuspend mechanism. HelmReleases are created in a suspended state and the platform-mesh-operator unsuspends them once the corresponding image resources have been processed. Set `suspend: true` in the profile to opt into this behavior.

### Dependencies

If your service needs another service to be ready first:

```yaml
my-service:
  dependsOn:
    - name: infra
      namespace: platform-mesh-system
  # ...
```

## Step 6: Local Prerelease Build Registration

To test your service locally with `task local-setup:prerelease`, register it in the build scripts.

### Add to Local Charts List

In `local-setup/scripts/ocm-build-local-charts.sh`, add your chart to `CUSTOM_LOCAL_COMPONENTS_CHART_PATHS`:

```bash
CUSTOM_LOCAL_COMPONENTS_CHART_PATHS=(
    # ... existing entries ...
    "my-service:charts/my-service"
)
```

### Add Version Resolution

In `local-setup/scripts/ocm-build-component.sh`, add a version resolution call in the `resolve_component_versions()` function:

```bash
get_component_version my-service github.com/platform-mesh/my-service charts/my-service MY_SERVICE_VERSION
```

### Add Component Reference

In `.ocm/component-constructor-prerelease.yaml`, add a componentReference in the top-level prerelease component:

```yaml
componentReferences:
  # ... existing references ...
  - name: my-service
    componentName: github.com/platform-mesh/my-service
    version: {{ .MY_SERVICE_VERSION }}
```

## Step 7: Testing Locally

After completing all the above steps:

```sh
# Full setup from scratch with local charts
task local-setup:prerelease

# Iterate on an existing cluster (faster)
task local-setup:prerelease:iterate

# Just rebuild and redeploy OCM component
task ocm:build ocm:apply
```

Verify your service is deployed:

```sh
kubectl get helmreleases -A | grep my-service
kubectl get pods -n platform-mesh-system | grep my-service
```

## Checklist

Use this checklist when adding a new service:

- [ ] **Chart created** at `charts/my-service/` with common dependency
- [ ] **Values documented** — run `task docs` after adding values
- [ ] **Unit tests** — add tests in `charts/my-service/tests/`
- [ ] **Workflow created** at `.github/workflows/my-service.yaml`
- [ ] **OCM constructor** — use existing shared template or create custom one in `.ocm/`
- [ ] **Profile updated** — service added to `default-profile.yaml` under `components.services`
- [ ] **Local build registered** — added to `ocm-build-local-charts.sh` and `ocm-build-component.sh`
- [ ] **Prerelease component reference** — added to `component-constructor-prerelease.yaml`
- [ ] **Image pipeline** — image repo publishes to `ghcr.io/platform-mesh/my-service`
- [ ] **Version update automation** — Renovate or workflow dispatch configured for appVersion bumps
- [ ] **Chart version bumped** — run `task update-changed` if other charts depend on yours
- [ ] **Local test passed** — verified with `task local-setup:prerelease`
