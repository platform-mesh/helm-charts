# portal

Helm Chart for the Platform Mesh Portal

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/openmfp/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/openmfp/helm-charts/tree/main/charts/common)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| auth.default.baseDomain | string | `""` | baseDomain used by the portal |
| auth.default.clientId | string | `""` | client id |
| auth.default.discoveryUrl | string | `""` | discovery url used for the idp |
| baseDomains[0] | string | `"localhost"` | base domains for VirtualService |
| cookieDomain | string | `"localhost"` | cookie domain |
| deployment.hostAliases | list | `[]` |  |
| developmentLandcsape | string | `"true"` | development landscape toggle |
| environment | string | `"local"` | environment |
| featureToggles | string | `"enableSessionAutoRefresh=true"` |  |
| frontendPort | int | `8000` | frontend port |
| health.liveness.path | string | `"/rest/health"` | path used for the liveness probe |
| health.port | int | `8080` | health port to be used by probes |
| health.readiness.path | string | `"/rest/health"` | path used for the readiness probe |
| health.startup.path | string | `"/rest/health"` | path used for the startup probe |
| http.protocol | string | `"http"` | protocol |
| image.name | string | `"ghcr.io/platform-mesh/portal"` |  |
| image.pullPolicyOverride | string | `"IfNotPresent"` |  |
| importContent | bool | `false` | import content toggle |
| kcp.kubeconfigSecret | string | `""` |  |
| kubeconfigSecret | string | `""` | allows the configuration of a kubeconfig secret for external api servers |
| validWebcomponentUrls | string | `".?"` |  |
| virtualService.hosts | list | `["*"]` | virtual service hosts |

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
