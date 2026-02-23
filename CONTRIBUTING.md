# Contributing to Platform Mesh

We want to make contributing to this project as easy and transparent as possible.

## Our development process

We use GitHub to track issues and feature requests, as well as accept pull requests.

## Issues

We use GitHub issues to track bugs. Please ensure your description is
clear and includes sufficient instructions to reproduce the issue.

## Pull requests

You are welcome to contribute with your pull requests. These steps explain the contribution process:

1. Fork the repository and create your branch from `main`.
1. Follow [Making changes](#Making changes).
1. If you've changed APIs, update the documentation.
1. Make sure the tests pass. Our github actions pipeline is running the unit and e2e tests for your PR and will indicate any issues.
1. Make your pull request against the `main` branch with a clear description of your changes and the problem they solve.
1. Sign the Developer Certificate of Origin (DCO).

## Making changes

Many of the developer workflow actions are automated via [Taskfile](https://taskfile.dev/).

A common workflow for a contributor after cloning the repository would be:

- Switch to a new branch
- Make your changes
- Commit your changes with a clear message
- Run `task lint` to ensure that your code follows the coding standards
- Run `task test` to verify that all tests are passing
    Note: Depending on your change this has to fail. If the helmtest snapshots have to be updated, run `task helmtest-update` and commit the updated snapshots.
- Run `task docs` to update the documentation based on the changes you made to the charts
- Bump the chart version of any chart you modified
- Run `task update-changed` to update the dependencies of other charts in this repository
- Test your changes with the [local-setup](local-setup/README.md)

> **NOTE:** You should always add if you are adding code repository.

## License

By contributing to Platform Mesh, you agree that your contributions will be licensed
under its [Apache-2.0 license](LICENSE).
