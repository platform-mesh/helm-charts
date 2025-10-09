> [!WARNING]
> This Repository is under development and not ready for productive use. It is in an alpha stage. That means APIs and concepts may change on short notice including breaking changes or complete removal of apis.

# platform-mesh - helm-charts

## Description

The helm-charts repository contains helm charts used for the deployment of platform-mesh instance on Kubernetes. It also contains CI/CD scripts for builidng and publishing relevant artefacts like charts and OCM components.

## Directory structure
- .github/workflows - GHA workflows to test, build and publish charts
- .ocm - OCM component constructor files for individual component references
- charts - a folder containing the HELM charts
- doc-templates - templates used to generate charts documentation
- local-setup - scripts and manifest used to bootstrap a local developer instance of platform-mesh
- Taskfile.yaml - script automation used by the [Taskfile](https://taskfile.dev/) cli

## Getting started

- For running and building the account-operator, please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file in this repository.
- To deploy the account-operator to kubernetes, please refer to the [helm-charts](https://github.com/platform-mesh/helm-charts) repository. 

## Tasks

Many of the developer workflow actions are automated via Taskfile. For example:
- `task test` to test all helm charts
- `task lint` to run linter for the charts
- `task docs` to update the README's based on values.yaml


## Templating

Chart documentation is generated automatically when running `task docs`.

## Releasing

The release is performed automatically through a GitHub Actions Workflow.

All the released versions will be available through access to GitHub (as any other Golang Module).

## Requirements

The helm-charts requires a installation of [Taskfile](https://taskfile.dev/).

## Contributing

Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file in this repository for instructions on how to contribute to platform-mesh. 

For detailed instructions regarding local development see local-setup [README.md](local-setup/README.md) and [README-developers.md](local-setup/README-developers.md)

## Code of Conduct

Please refer to the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) file in this repository informations on the expected Code of Conduct for contributing to platform-mesh.

## Licensing

Copyright 2025 SAP SE or an SAP affiliate company and platform-mesh contributors. Please see our [LICENSE](LICENSE) for copyright and license information. Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/platform-mesh/helm-charts).
