# account-operator

A Helm chart to deploy platform-mesh Account-Operator

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/platform-mesh/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/common)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `account-operator-crds` | The `account-operator-crds` chart provides CRDS introduced by the `account-operator`. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/account-operator-crds)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crds.enabled | bool | `true` | Enable CRDs |
| deployment.hostAliases | list | `[]` |  |
| deployment.replicas | int | `1` |  |
| deployment.specTemplate.annotations | object | `{}` | The annotations for the deployment |
| deployment.specTemplate.labels | object | `{}` | The labels for the deployment |
| image.name | string | `"ghcr.io/platform-mesh/account-operator"` | The image repository |
| kcp | object | `{"apiExportEndpointSliceName":"core.platform-mesh.io","enabled":false,"virtualWorkspaceUrl":""}` | The KCP configuration |
| kcp.apiExportEndpointSliceName | string | `"core.platform-mesh.io"` | KCP APIExportEndpointSliceName |
| kcp.enabled | bool | `false` | Enable KCP |
| kcp.virtualWorkspaceUrl | string | `""` | The URL for the virtual workspace |
| kubeconfigSecret | string | `""` | The secret for kubeconfig |
| operator.leaderElect | bool | `true` |  |
| security.mountServiceAccountToken | bool | `true` | Mount the service account token |
| subroutines.extension.enabled | bool | `true` | Enable extension subroutines |
| subroutines.extensionReady.enabled | bool | `true` | Enable extension ready subroutines |
| subroutines.fga.creatorRelation | string | `"owner"` | The creator relation for FGA |
| subroutines.fga.enabled | bool | `true` | Enable FGA subroutines |
| subroutines.fga.grpcAddr | string | `"platform-mesh-openfga:8081"` | The gRPC address for FGA |
| subroutines.fga.objectType | string | `"core_platform-mesh_io_account"` | The object type for FGA |
| subroutines.fga.parentRelation | string | `"parent"` | The parent relation for FGA |
| subroutines.fga.rootNamespace | string | `"platform-mesh-root"` | The root namespace for FGA |
| subroutines.namespace.enabled | bool | `true` | Enable namespace subroutines |
| webhooks.certDir | string | `"/certs"` | The directory for webhook certificates |
| webhooks.denyList | list | `["admin","root","system","www"]` | List of denied organization names |
| webhooks.enabled | bool | `true` | Enable webhooks |
| webhooks.register | bool | `false` | Register webhooks, flag to toggle if webhooks should be registered on the runtime cluster |

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
