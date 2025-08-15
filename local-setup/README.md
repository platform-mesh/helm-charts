# OpenMFP - Getting Started

[![test](https://github.com/fluxcd/flux2-kustomize-helm-example/workflows/test/badge.svg)](https://github.com/fluxcd/flux2-kustomize-helm-example/actions)
[![e2e](https://github.com/fluxcd/flux2-kustomize-helm-example/workflows/e2e/badge.svg)](https://github.com/fluxcd/flux2-kustomize-helm-example/actions)
[![license](https://img.shields.io/github/license/fluxcd/flux2-kustomize-helm-example.svg)](https://github.com/fluxcd/flux2-kustomize-helm-example/blob/main/LICENSE)

For this example we create a functioning local setup using kind.
The end goal is to leverage Flux and Kustomize to manage the cluster.

We will configure Flux to install, test and upgrade a demo app using
`OCIRepository` and `HelmRelease` custom resources.
Flux will monitor the Helm repository, and it will automatically
upgrade the Helm releases to their latest chart version based on semver ranges.

## Prerequisites

- [Docker](https://www.docker.com) or [podman](https://podman.io): install either docker or podman in order to run the kind cluster
- [Kind](https://kind.sigs.k8s.io/): In order to have a local kubernetes cluster you can use kind. Kind Installation: [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
  On macOS using Homebrew:
  ```sh
  brew install kind
  ```
- [Helm](https://helm.sh/): In order to bootstrap flux, helm is required. Checkout various ways to install helm [here](https://helm.sh/docs/intro/install/)
  On macOS using Homebrew:
  ```sh
  brew install helm
  ```
- Either specify your github.com username using the `GH_USER` environment variable OR install the gh cli using:
    ```sh
    brew install gh
    ```
- Tooling binaries: yq, base64, mkcert, kubectl

## Bootstrap local environment

The `scripts/start.sh` contains all steps needed to bootstrap the local environment. The script will automate the following steps:
- Create kind cluster called `openmfp`
- install flux
- prepare secrets

```sh
## [Secrets]: configure the following environment variables:
export KEYCLOAK_SECRET='' # client secret for the 'openmfp' keycloak client
export GH_TOKEN='' # token used to pull the openmfp docker images
```
- apply flux deployment configuration

To start the bootstrapping and local installation invoke
```sh
./local-setup/scripts/start.sh
```

To test local packages, without releasing them via ghcr.io, use the local-setup task:
```sh
task local-setup
```
this will package and push the helm charts to a local OCI registry and spin off KIND cluster which will use them. Make sure to update the chart dependencies and version references in local-setup/kustomize before running the script.

Once the process is completed you can access the environment using https://portal.dev.local

# Optional Steps

- Keycloak client secret: It is possible to set a custom keycloak client secret by setting the `KEYCLOAK_SECRET` environment variable before running the boostrap script.

## Running e2e Playwright tests
```sh
task e2e-test
```