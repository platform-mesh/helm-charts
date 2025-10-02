# Developer documentation

This section is more advanced information for chart developers who want to test their changes locally, without going through the official release process for OCM components and charts.

The steps below describe a procedure to be followed when a developer changes a chart and wants to try it out within a local-setup environment.

## Bootstrap with locally built OCM components (circumvents deployment of released components)

Prerequisite: `task local-setup` or `task local-setup-cached` must be run and complete successfully, before the steps below are executed. They require a functioning local-setup environment to work.

To test local charts, run the local-setup script and make modifications to the chars while bumping the version in Chart.yaml. The follow the steps:

Steps:

- (optional) edit Taskfile.yaml and configure `COMPONENT_PRERELEASE_VERSION`, `CUSTOM_LOCAL_COMPONENTS_CHART_PATHS` and `COMPONENT_VERSION_FIX_DEPEDENCY_VERSIONS` parameters as needed
- (optional) if adding new componentReferences, update [.ocm/component-constructor-prerelease.yaml](.ocm/component-constructor-prerelease.yaml)
- run `task ocm:deploy` to deploy the OCM infrastructure components. This needs to be called just once.
- run `task ocm:build:component` to build the OCM components (top level `prerelease` and all component references)
- run `task ocm:kustomize:apply` to apply component changesto the cluster
- repeat last 2 steps when doing changes to the charts or alternatively call `task ocm:build-apply:iterate` which will do the same
- run `task ocm:cleanup` for Cleanup when needed
