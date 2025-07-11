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

