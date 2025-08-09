# platform-mesh

The Platform Mesh chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| components.example-content.enabled | bool | `true` |  |
| components.extension-manager-operator.enabled | bool | `true` |  |
| components.infra.enabled | bool | `true` |  |
| components.keycloak.enabled | bool | `false` |  |
| components.portal.enabled | bool | `false` |  |

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
# platform-mesh

![Version: 0.0.662](https://img.shields.io/badge/Version-0.0.662-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.0](https://img.shields.io/badge/AppVersion-0.0.0-informational?style=flat-square)

The Platform Mesh chart for Kubernetes

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../example-content | example-content | 0.114.40 |
| file://../extension-manager-operator | extension-manager-operator | 0.30.96 |
| file://../infra | infra | 0.63.4 |
| file://../keycloak | keycloak | 0.64.13 |
| file://../portal | portal | 0.74.12 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| components.example-content.enabled | bool | `true` |  |
| components.extension-manager-operator.enabled | bool | `true` |  |
| components.infra.enabled | bool | `true` |  |
| components.keycloak.enabled | bool | `false` |  |
| components.portal.enabled | bool | `false` |  |

