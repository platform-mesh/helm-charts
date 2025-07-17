# virtual-workspaces

A Helm chart to deploy platform-mesh virtual-workspaces

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/platform-mesh/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/common)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `account-operator-crds` | The `account-operator-crds` chart provides CRDS introduced by the `account-operator`. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/account-operator-crds)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| authenticationKubeconfigSecretName | string | `"portal-kubeconfig"` |  |
| clientCASecretName | string | `"kcp-ca"` |  |
| deployment.contentForLabel | string | `""` |  |
| deployment.entityLabel | string | `""` |  |
| deployment.providerWorkspaceId | string | `""` |  |
| deployment.resourceSchemaName | string | `""` |  |
| deployment.resourceSchemaWorkspace | string | `""` |  |
| deployment.serverUrl | string | `"https://kcp-front-proxy.openmfp-system:8443"` |  |
| image.name | string | `"ghcr.io/platform-mesh/virtual-workspaces"` | The image repository |
| kubeconfigSecretName | string | `"account-operator-kubeconfig"` |  |
| requestHeaderClientCASecretName | string | `"kcp-requestheader-client-ca"` |  |
| service.port | int | `8443` |  |
| virtualWorkspaceSecretName | string | `"kcp-virtual-workspaces-cert"` |  |

## Overriding Values

The values in the `defaults:` section can be reused from other charts by using the lookup function "common.getKeyValue". It implements lookup on three levels:

1. Looks for `keyOverride` in the chart's values.yaml
2. Looks for `global.key` in the chart's or parent chart's values.yaml
3. Uses the `key` in the chart's values.yaml
4. Uses the `common.defaults.key` value from the table below.

1 has precedence over 2 over 3 over 4 respectively. This approach allows for individual charts to have minimal configuration, while still being able to override parameters locally.

Example
```
1) .Values.deployment.resources.limits.memoryOverride = 4096MB
2) .Values.global.deployment.resources.limits.memory = 2048MB
3) .Values.deployment.resources.limits.memory = 1024MB
4) .Values.common.defaults.deployment.resources.limits.memory = default 512MB
```
