# platform-mesh - helm-charts

> [!WARNING]
> This Repository is under development and not ready for productive use. It is in an alpha stage. That means APIs and concepts may change on short notice including breaking changes or complete removal of apis.

## Description

The helm-charts repository contains helm charts used for the deployment of platform-mesh instance on Kubernetes. It also contains CI/CD scripts for buildidng and publishing relevant artefacts like charts and OCM components.

## Directory structure

- .github/workflows - GHA workflows to test, build and publish charts
- .ocm - OCM component constructor files for individual component references
- charts - a folder containing the HELM charts
- doc-templates - templates used to generate charts documentation
- local-setup - scripts and manifest used to bootstrap a local developer instance of platform-mesh
- Taskfile.yaml - script automation used by the [Taskfile](https://taskfile.dev/) cli

## Getting started

- For running and building the local-setup, please refer to the [local-setup readme](local-setup/README.md) file in this repository.
<!--
TODO:
- To deploy the Platform Mesh to kubernetes, please refer to ...
-->

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

For detailed instructions regarding local development see local-setup [README.md](local-setup/README.md) and [DEVELOPERS.md](local-setup/DEVELOPERS.md)

## Code of Conduct

Please refer to our [Code of Conduct](https://github.com/platform-mesh/.github/blob/main/CODE_OF_CONDUCT.md) for information on the expected conduct for contributing to Platform Mesh.