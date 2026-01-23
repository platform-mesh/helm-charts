# iam-ui

Helm Chart for the iam-ui

## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| deployment.maxSurge | int | `5` |  |
| deployment.maxUnavailable | int | `0` |  |
| exposure.hostnames | list | `["portal.localhost","*.portal.localhost"]` | hostnames to be used for exposure |
| gatewayApi.httpRoute.corsFilters | list | `[{"extensionRef":{"group":"traefik.io","kind":"Middleware","name":"cors-header"},"type":"ExtensionRef"}]` | CORS filter referencing traefik middleware (used when traefik.enabled=true) |
| gatewayApi.httpRoute.filters | list | `[]` | list of HTTPRoute filters (default: none) |
| gatewayApi.httpRoute.parentRefs[0].name | string | `"k8sapi-gateway"` |  |
| gatewayApi.httpRoute.pathPrefix | string | `"/ui/iam"` |  |
| health.port | int | `8080` |  |
| health.readiness.path | string | `"/healthz"` |  |
| health.startup.path | string | `"/healthz"` |  |
| image.name | string | `"ghcr.io/platform-mesh/iam-ui"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| port | int | `8080` |  |
| traefik.enabled | bool | `true` | toggle to enable traefik CORS filter in HTTPRoute |

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
