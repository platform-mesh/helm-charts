# example-content

Helm Chart for the Platform Mesh Portal

## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| contentConfigurations.ui.enabled | bool | `true` |  |
| contentConfigurations.ui.internalUrl | string | `"http://platform-mesh-example-content.platform-mesh-system.svc.cluster.local:8080/ui/example-content/ui/assets/config.json"` |  |
| contentConfigurations.ui.url | string | `"http://localhost:8000/ui/example-content/ui/assets/config.json"` |  |
| contentConfigurations.wc.enabled | bool | `true` |  |
| contentConfigurations.wc.internalUrl | string | `"http://platform-mesh-example-content.platform-mesh-system.svc.cluster.local:8080/ui/example-content/wc/assets/config.json"` |  |
| contentConfigurations.wc.url | string | `"http://localhost:8000/ui/example-content/wc/assets/config.json"` |  |
| contentProtocolDomain | string | `"https://example-content.some-domain.com"` |  |
| image.name | string | `"ghcr.io/platform-mesh/example-content"` | The image name |
| istio.enabled | bool | `true` |  |
| istio.virtualService.hosts[0] | string | `"*"` |  |
| istio.virtualService.matchers[0].match[0].uri.prefix | string | `"/ui/example-content"` |  |
| security.mountServiceAccountToken | bool | `false` |  |

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
# example-content

![Version: 0.114.40](https://img.shields.io/badge/Version-0.114.40-informational?style=flat-square) ![AppVersion: v0.158.15](https://img.shields.io/badge/AppVersion-v0.158.15-informational?style=flat-square)

Helm Chart for the Platform Mesh Portal

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/platform-mesh/helm-charts | common | 0.5.5 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| contentConfigurations.ui.enabled | bool | `true` |  |
| contentConfigurations.ui.internalUrl | string | `"http://platform-mesh-example-content.platform-mesh-system.svc.cluster.local:8080/ui/example-content/ui/assets/config.json"` |  |
| contentConfigurations.ui.url | string | `"http://localhost:8000/ui/example-content/ui/assets/config.json"` |  |
| contentConfigurations.wc.enabled | bool | `true` |  |
| contentConfigurations.wc.internalUrl | string | `"http://platform-mesh-example-content.platform-mesh-system.svc.cluster.local:8080/ui/example-content/wc/assets/config.json"` |  |
| contentConfigurations.wc.url | string | `"http://localhost:8000/ui/example-content/wc/assets/config.json"` |  |
| contentProtocolDomain | string | `"https://example-content.some-domain.com"` |  |
| image.name | string | `"ghcr.io/platform-mesh/example-content"` | The image name |
| istio.enabled | bool | `true` |  |
| istio.virtualService.hosts[0] | string | `"*"` |  |
| istio.virtualService.matchers[0].match[0].uri.prefix | string | `"/ui/example-content"` |  |
| security.mountServiceAccountToken | bool | `false` |  |

