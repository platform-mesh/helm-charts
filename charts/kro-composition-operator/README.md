# kro-composition-operator

A Helm chart to deploy the platform-mesh kro composition operator (KROaaS)

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hostAliases.enabled | bool | `false` |  |
| hostAliases.values | list | `[]` |  |
| image.digest | string | `""` | The image digest (when set, overrides tag: registry/repository@digest) |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.registry | string | `"ghcr.io"` | The image registry |
| image.repository | string | `"platform-mesh/platform-mesh/kro-composition-operator"` | The image repository path (without registry) |
| image.tag | string | `""` | Image tag; defaults to the chart appVersion when empty |
| kcp.apiExportEndpointSlice | string | `"kro.run"` | APIExportEndpointSlice serving the kro.run RGD API |
| kcp.providerWorkspace | string | `"root:providers:kro-provider"` | Workspace path holding the kro.run APIExport + endpointslice |
| kubeconfigSecret | string | `"kcp-kubeconfig"` | Name of the Secret holding the operator's kcp kubeconfig (from the provider    connection). Mounted at /kubeconfig/kubeconfig and passed via --kubeconfig. |
| leaderElect | bool | `false` | Enable leader election Leader election targets the kcp provider workspace (the manager's config) for its lease; left off for single-replica local runs. Revisit for multi-replica HA. |
| replicas | int | `1` | Number of operator replicas |
| resources.limits.memory | string | `"256Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"128Mi"` |  |

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
# kro-composition-operator

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

A Helm chart to deploy the platform-mesh kro composition operator (KROaaS)

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/platform-mesh/helm-charts | common | 0.13.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hostAliases.enabled | bool | `false` |  |
| hostAliases.values | list | `[]` |  |
| image.digest | string | `""` | The image digest (when set, overrides tag: registry/repository@digest) |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.registry | string | `"ghcr.io"` | The image registry |
| image.repository | string | `"platform-mesh/platform-mesh/kro-composition-operator"` | The image repository path (without registry) |
| image.tag | string | `""` | Image tag; defaults to the chart appVersion when empty |
| kcp.apiExportEndpointSlice | string | `"kro.run"` | APIExportEndpointSlice serving the kro.run RGD API |
| kcp.providerWorkspace | string | `"root:providers:kro-provider"` | Workspace path holding the kro.run APIExport + endpointslice |
| kubeconfigSecret | string | `"kcp-kubeconfig"` | Name of the Secret holding the operator's kcp kubeconfig (from the provider    connection). Mounted at /kubeconfig/kubeconfig and passed via --kubeconfig. |
| leaderElect | bool | `false` | Enable leader election Leader election targets the kcp provider workspace (the manager's config) for its lease; left off for single-replica local runs. Revisit for multi-replica HA. |
| replicas | int | `1` | Number of operator replicas |
| resources.limits.memory | string | `"256Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"128Mi"` |  |

