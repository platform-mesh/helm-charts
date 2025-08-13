# extension-manager-operator

A Helm chart for extension-manager-operator which manages resources like ContentConfigurations and exposes REST `/validate` endpoint

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/openmfp/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/openmfp/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/openmfp/helm-charts/tree/main/charts/common)|
| `oci://ghcr.io/openmfp/helm-charts` | `extension-manager-operator-crds` | The `extension-manager-operator-crds` chart provides CRDS introduced by the `extension-manager-operator`. |[source](https://github.com/openmfp/helm-charts/tree/main/charts/extension-manager-operator-crds)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| commonAnnotations | object | `{}` |  |
| crds.enabled | bool | `true` |  |
| image.name | string | `"ghcr.io/platform-mesh/extension-manager-operator"` |  |
| istio.enabled | bool | `false` | enable Istio VirtualService |
| kcp.enabled | bool | `false` | enable the kcp mode of the operator |
| kcp.kubeconfigSecret | string | `""` | name the secret that holds the kubeconfig for the kcp mode |
| kubeconfigSecret | string | `""` |  |
| validationServer.host | string | `"*"` | host for the validation VirtualService |
| validationServer.port | int | `8088` | port for the validation server |

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
