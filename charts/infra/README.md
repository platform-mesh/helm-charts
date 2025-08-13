# infra

The infra platform-mesh chart configures a number of common infrastructure components for the Platform Mesh platform.

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/platform-mesh/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/common)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crossplane.enabled | bool | `true` |  |
| fga.enabled | bool | `false` |  |
| fga.stores | list | `[]` |  |
| istio.enabled | bool | `true` |  |
| istio.gateway.annotations | object | `{}` |  |
| istio.gateway.apiVersion | string | `"networking.istio.io/v1"` |  |
| istio.gateway.name | string | `"gateway"` |  |
| istio.gateway.selector.istio | string | `"gateway"` |  |
| istio.main.gateway.hosts[0] | string | `"*"` |  |
| istio.main.gateway.name | string | `"http"` |  |
| istio.main.gateway.port | int | `8000` |  |
| istio.main.gateway.protocol | string | `"HTTP"` |  |
| istio.networking.apiVersion | string | `"networking.istio.io/v1"` |  |
| istio.passThrough.gateway.enabled | bool | `false` |  |
| istio.serviceEntries.https.enabled | bool | `false` |  |
| istio.serviceEntries.https.hosts | list | `[]` |  |
| kcp.clientCertIssuer | string | `"kcp-client-issuer"` |  |
| kcp.enabled | bool | `false` |  |

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
