# platform-mesh - helm-charts

> [!WARNING]
> This Repository is under development and not ready for productive use. It is in an alpha stage. That means APIs and concepts may change on short notice including breaking changes or complete removal of apis.

## Description

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/platform-mesh/helm-charts/badge)](https://scorecard.dev/viewer/?uri=github.com/platform-mesh/helm-charts)

The helm-charts repository contains helm charts used for the deployment of platform-mesh instance on Kubernetes. It also contains CI/CD scripts for buildidng and publishing relevant artefacts like charts and OCM components.

## Directory structure

- .github/workflows - GHA workflows to test, build and publish charts
- .ocm - OCM component constructor files for individual component references
- charts - a folder containing the HELM charts
- installation - Installation: pure Helm/Kustomize manifests to deploy Platform Mesh to a Kubernetes cluster (the default path)
- development - Developer setup: bring up Platform Mesh locally on kind, either from published components (PINNED, default) or built locally (DEV)
- doc-templates - templates used to generate charts documentation
- Taskfile.yaml - script automation used by the [Taskfile](https://taskfile.dev/) cli

## Getting started

- **Installing Platform Mesh** (the default path): follow the [Installation guide](installation/README.md) to deploy to a Kubernetes cluster with Helm and Kustomize.
- **Evaluating or developing locally**: follow the [Developer setup](development/README.md) to run Platform Mesh on a local kind cluster.
- For adding a new service to PlatformMesh, see the [Adding a Service](docs/adding-a-service.md) guide.
## Releasing

The release is performed automatically through a GitHub Actions Workflow.

All the released versions will be available through access to GitHub (as any other Golang Module).

## Requirements

The following is required to work with the helm charts in this repository:

- [helm](https://helm.sh) to work with the helm charts
- [ct](https://helm.sh/docs/topics/chart_testing/) to run the tests for the charts
- [Taskfile](https://taskfile.dev/) to run the tasks in Taskfile.yaml
- [kind](https://kind.sigs.k8s.io/) to run the local Kubernetes cluster for testing and development

## Contributing

Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file in this repository for instructions on how to contribute to platform-mesh.

For detailed instructions regarding local development see the Developer setup [README.md](development/README.md).

## Code of Conduct

Please refer to our [Code of Conduct](https://github.com/platform-mesh/.github/blob/main/CODE_OF_CONDUCT.md) for information on the expected conduct for contributing to Platform Mesh.

<p align="center"><img alt="Bundesministerium für Wirtschaft und Energie (BMWE)-EU funding logo" src="https://apeirora.eu/assets/img/BMWK-EU.png" width="400"/></p>
