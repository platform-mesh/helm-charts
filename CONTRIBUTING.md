## Overview

# Contributing to Platform Mesh Helm Charts
We want to make contributing to this project as easy and transparent as possible.

## Our development process
We use GitHub to track issues and feature requests, as well as accept pull requests.

## Pull requests
You are welcome to contribute with your pull requests. These steps explain the contribution process:

1. Fork the repository and create your branch from `main`.
1. Add tests for your changes.
1. If you've changed values or docs, update chart documentation by running `task docs`.
1. Make sure the tests pass. Our GitHub Actions pipeline runs unit and e2e tests for your PR.
1. Sign the Developer Certificate of Origin (DCO).

## Testing

> NOTE: Always add tests when you add code.
To run chart tests locally:

```
helm unittest -u <PATH TO CHART>
```

To bootstrap local charts using a local OCI registry, package the charts then run start with `oci`:

```
task helmpackage
./local-setup/scripts/start.sh oci
```

Ensure chart versions are referenced correctly in OCIRepository patches before running the start script.

To reference local chart dependencies (for development), you can temporarily point to a local folder:

```
apiVersion: v2
name: platform-mesh
description: The Platform Mesh chart for Kubernetes
type: application
version: 0.0.1
appVersion: "0.0.0"

dependencies:
  - name: keycloak
    version: 0.64.12
    repository: file://../keycloak
    condition: components.keycloak.enabled
```

After such change, increment the `version` and run `helm dependency update` on dependencies first and then on the top-level chart. Bump patch versions to reflect your changes.

## Issues
We use GitHub issues to track bugs. Please ensure your description is clear and includes sufficient instructions to reproduce the issue.

## License
By contributing to this repository, you agree your contributions will be licensed under the [Apache-2.0 license](LICENSE).
