## Overview

# Contributing to Platform Mesh
We want to make contributing to this project as easy and transparent as possible.

## Our development process
We use GitHub to track issues and feature requests, as well as accept pull requests.

## Pull requests
You are welcome to contribute with your pull requests. These steps explain the contribution process:

1. Fork the repository and create your branch from `main`.
1. [Add tests](#testing) for your code.
1. If you've changed APIs like values, update the chart documentation by running `task helm-docs`. 
1. Make sure the tests pass. Our github actions pipeline is running the unit and e2e tests for your PR and will indicate any issues.
1. Sign the Developer Certificate of Origin (DCO).

## Testing

> **NOTE:** You should always add tests if you are adding code to our repository.
To let chart tests run locally, run `helm unittest -u <PATH TO CHART>`.

To start bootstrapping using the local charts from a local oci repository, package the charts and run the string with the `oci` parameter:
```sh
task helmpackage
./local-setup/scripts/start.sh oci
```

Also ensure the proper chart versions are referenced in the OCIRepository patches, before running the start script. 

To reference local chart dependencies, change the Chart.yaml file to point to local chart folder like so:
```yaml
apiVersion: v2
name: platform-mesh
description: The Platform Mesh chart for Kubernetes
type: application
version: 0.0.194
appVersion: "0.0.0"

dependencies:
  - name: keycloak
    version: 0.61.0
    repository: file://../keycloak
    condition: components.keycloak.enabled
```

After such change, Increment the `version` and make sure to run `helm dependency update` on to dependencies first and last on the top-level chart which links them. Update the patch versions to reflect your changes.

## Issues
We use GitHub issues to track bugs. Please ensure your description is
clear and includes sufficient instructions to reproduce the issue.

## License
By contributing to Platform Mesh, you agree that your contributions will be licensed
under its [Apache-2.0 license](LICENSE).
