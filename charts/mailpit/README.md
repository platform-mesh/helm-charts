# mailpit

A Helm chart to deploy Mailpit - a web and API based SMTP testing tool

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| domain.pathPrefix | string | `"/mailpit"` |  |
| hosts[0] | string | `"portal.dev.local"` |  |
| image.name | string | `"axllent/mailpit"` |  |
| istio.enabled | bool | `true` |  |
| istio.gateway.name | string | `"gateway"` |  |

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
# mailpit

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1.27.9](https://img.shields.io/badge/AppVersion-v1.27.9-informational?style=flat-square)

A Helm chart to deploy Mailpit - a web and API based SMTP testing tool

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/platform-mesh/helm-charts | common | 0.5.6 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| domain.pathPrefix | string | `"/mailpit"` |  |
| hosts[0] | string | `"portal.dev.local"` |  |
| image.name | string | `"axllent/mailpit"` |  |
| istio.enabled | bool | `true` |  |
| istio.gateway.name | string | `"gateway"` |  |

