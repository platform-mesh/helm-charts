# platform-mesh

The Platform Mesh chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `portal` | The platform-mesh portal chart. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/portal)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `example-content` | The platform-mesh example-content chart. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/example-content)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `infra` | The platform-mesh infra chart. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/infra)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `extension-manager-operator` | The platform-mesh extension-manager-operator chart. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/extension-manager-operator)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| components.example-content.enabled | bool | `true` |  |
| components.extension-manager-operator.enabled | bool | `true` |  |
| components.infra.enabled | bool | `true` |  |
| components.keycloak.enabled | bool | `true` |  |
| components.portal.enabled | bool | `true` |  |

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
