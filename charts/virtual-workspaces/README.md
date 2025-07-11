
## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/platform-mesh/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/common)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `account-operator-crds` | The `account-operator-crds` chart provides CRDS introduced by the `account-operator`. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/account-operator-crds)|
# virtual-workspaces

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.0.1](https://img.shields.io/badge/AppVersion-v0.0.1-informational?style=flat-square)

A Helm chart to deploy platform-mesh virtual-workspaces

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../common | common | 0.5.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| deployment.contentForLabel | string | `""` |  |
| deployment.entityLabel | string | `""` |  |
| deployment.providerWorkspaceId | string | `""` |  |
| deployment.resourceSchemaName | string | `""` |  |
| deployment.resourceSchemaWorkspace | string | `""` |  |
| deployment.serverUrl | string | `""` |  |
| image.name | string | `"ghcr.io/platform-mesh/virtual-workspaces"` | The image repository |
| kubeconfigSecretName | string | `"account-operator-kubeconfig"` |  |
| service.port | int | `8443` |  |
| virtualWorkspaceSecretName | string | `"kcp-virtual-workspaces-cert"` |  |

