# kubernetes-graphql-gateway

Basic helm chart that contains listener and gateway

## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cors.allowedHeaders | string | `"*"` |  |
| cors.allowedOrigins | string | `"*"` |  |
| cors.enabled | bool | `false` |  |
| deployment.maxSurge | int | `5` |  |
| deployment.maxUnavailable | int | `0` |  |
| deployment.replicas | int | `1` |  |
| deployment.revisionHistoryLimit | int | `3` |  |
| extraEnvs | list | `[]` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| gateway.graphiql | bool | `true` |  |
| gateway.healthCheck.enabled | bool | `true` |  |
| gateway.healthCheck.port | int | `3389` |  |
| gateway.logLevel | string | `"trace"` |  |
| gateway.metricsPort | int | `8081` |  |
| gateway.port | int | `8080` |  |
| gateway.resources.limits.memory | string | `"1200Mi"` |  |
| gateway.resources.requests.cpu | string | `"250m"` |  |
| gateway.resources.requests.memory | string | `"1000Mi"` |  |
| gateway.shouldImpersonate | bool | `true` |  |
| gateway.usernameClaim | string | `"email"` |  |
| health.liveness.failureThreshold | int | `1` |  |
| health.liveness.path | string | `"/healthz"` |  |
| health.liveness.periodSeconds | int | `10` |  |
| health.periodSeconds | int | `10` |  |
| health.readiness.initialDelaySeconds | int | `5` |  |
| health.readiness.path | string | `"/readyz"` |  |
| health.readiness.periodSeconds | int | `10` |  |
| health.startup.failureThreshold | int | `30` |  |
| health.startup.path | string | `"/readyz"` |  |
| health.startup.periodSeconds | int | `10` |  |
| image.name | string | `"ghcr.io/platform-mesh/kubernetes-graphql-gateway"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| istio.enabled | bool | `true` |  |
| istio.gateway.name | string | `"gateway"` |  |
| kcp.enabled | bool | `true` |  |
| kubeConfig.createSecret | bool | `false` |  |
| kubeConfig.enabled | bool | `false` |  |
| kubeConfig.secretName | string | `"kcp-root-kubeconfig"` |  |
| listener.apiExportName | string | `"kcp.io"` |  |
| listener.healthCheck.enabled | bool | `true` |  |
| listener.healthCheck.port | int | `3390` |  |
| listener.metricsPort | int | `8091` |  |
| listener.port | int | `8090` |  |
| listener.resources.limits.memory | string | `"600Mi"` |  |
| listener.resources.requests.cpu | string | `"250m"` |  |
| listener.resources.requests.memory | string | `"500Mi"` |  |
| listener.virtualWorkspacesConfig.configMapName | string | `"virtual-workspaces-config"` |  |
| listener.virtualWorkspacesConfig.content.virtualWorkspaces | list | `[]` |  |
| listener.virtualWorkspacesConfig.enabled | bool | `false` |  |
| listener.virtualWorkspacesConfig.path | string | `"/app/config/virtual-workspaces.yaml"` |  |
| resources.limits.memory | string | `"1800Mi"` |  |
| resources.requests.cpu | string | `"500m"` |  |
| resources.requests.memory | string | `"1500Mi"` |  |
| sentry.environment | string | `"dev"` |  |
| tracing.enabled | bool | `true` |  |
| virtualService.hosts[0] | string | `"*"` |  |
| virtualService.httpRules[0].cors.allowHeaders[0] | string | `"*"` |  |
| virtualService.httpRules[0].cors.allowMethods[0] | string | `"GET"` |  |
| virtualService.httpRules[0].cors.allowMethods[1] | string | `"POST"` |  |
| virtualService.httpRules[0].cors.allowOrigins[0].regex | string | `".*"` |  |
| virtualService.httpRules[0].name | string | `"default"` |  |
| virtualService.pathPrefix | string | `"/kubernetes-graphql-gateway/"` |  |

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
# kubernetes-graphql-gateway

![Version: 0.20.32](https://img.shields.io/badge/Version-0.20.32-informational?style=flat-square) ![AppVersion: v0.83.3](https://img.shields.io/badge/AppVersion-v0.83.3-informational?style=flat-square)

Basic helm chart that contains listener and gateway

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/platform-mesh/helm-charts | common | 0.5.5 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cors.allowedHeaders | string | `"*"` |  |
| cors.allowedOrigins | string | `"*"` |  |
| cors.enabled | bool | `false` |  |
| deployment.maxSurge | int | `5` |  |
| deployment.maxUnavailable | int | `0` |  |
| deployment.replicas | int | `1` |  |
| deployment.revisionHistoryLimit | int | `3` |  |
| extraEnvs | list | `[]` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| gateway.graphiql | bool | `true` |  |
| gateway.healthCheck.enabled | bool | `true` |  |
| gateway.healthCheck.port | int | `3389` |  |
| gateway.logLevel | string | `"trace"` |  |
| gateway.metricsPort | int | `8081` |  |
| gateway.port | int | `8080` |  |
| gateway.resources.limits.memory | string | `"1200Mi"` |  |
| gateway.resources.requests.cpu | string | `"250m"` |  |
| gateway.resources.requests.memory | string | `"1000Mi"` |  |
| gateway.shouldImpersonate | bool | `true` |  |
| gateway.usernameClaim | string | `"email"` |  |
| health.liveness.failureThreshold | int | `1` |  |
| health.liveness.path | string | `"/healthz"` |  |
| health.liveness.periodSeconds | int | `10` |  |
| health.periodSeconds | int | `10` |  |
| health.readiness.initialDelaySeconds | int | `5` |  |
| health.readiness.path | string | `"/readyz"` |  |
| health.readiness.periodSeconds | int | `10` |  |
| health.startup.failureThreshold | int | `30` |  |
| health.startup.path | string | `"/readyz"` |  |
| health.startup.periodSeconds | int | `10` |  |
| image.name | string | `"ghcr.io/platform-mesh/kubernetes-graphql-gateway"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| istio.enabled | bool | `true` |  |
| istio.gateway.name | string | `"gateway"` |  |
| kcp.enabled | bool | `true` |  |
| kubeConfig.createSecret | bool | `false` |  |
| kubeConfig.enabled | bool | `false` |  |
| kubeConfig.secretName | string | `"kcp-root-kubeconfig"` |  |
| listener.apiExportName | string | `"kcp.io"` |  |
| listener.healthCheck.enabled | bool | `true` |  |
| listener.healthCheck.port | int | `3390` |  |
| listener.metricsPort | int | `8091` |  |
| listener.port | int | `8090` |  |
| listener.resources.limits.memory | string | `"600Mi"` |  |
| listener.resources.requests.cpu | string | `"250m"` |  |
| listener.resources.requests.memory | string | `"500Mi"` |  |
| listener.virtualWorkspacesConfig.configMapName | string | `"virtual-workspaces-config"` |  |
| listener.virtualWorkspacesConfig.content.virtualWorkspaces | list | `[]` |  |
| listener.virtualWorkspacesConfig.enabled | bool | `false` |  |
| listener.virtualWorkspacesConfig.path | string | `"/app/config/virtual-workspaces.yaml"` |  |
| resources.limits.memory | string | `"1800Mi"` |  |
| resources.requests.cpu | string | `"500m"` |  |
| resources.requests.memory | string | `"1500Mi"` |  |
| sentry.environment | string | `"dev"` |  |
| tracing.enabled | bool | `true` |  |
| virtualService.hosts[0] | string | `"*"` |  |
| virtualService.httpRules[0].cors.allowHeaders[0] | string | `"*"` |  |
| virtualService.httpRules[0].cors.allowMethods[0] | string | `"GET"` |  |
| virtualService.httpRules[0].cors.allowMethods[1] | string | `"POST"` |  |
| virtualService.httpRules[0].cors.allowOrigins[0].regex | string | `".*"` |  |
| virtualService.httpRules[0].name | string | `"default"` |  |
| virtualService.pathPrefix | string | `"/kubernetes-graphql-gateway/"` |  |

