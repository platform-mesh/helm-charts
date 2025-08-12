# portal

Helm Chart for the Platform Mesh Portal

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/openmfp/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/openmfp/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/openmfp/helm-charts/tree/main/charts/common)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| baseDomains[0] | string | `"localhost"` |  |
| cookieDomain | string | `"localhost"` |  |
| developmentLandcsape | string | `"true"` |  |
| environment | string | `"local"` |  |
| extraEnvVars[0].name | string | `"PLATFORM_MESH_PORTAL_CONTEXT_CRD_GATEWAY_API_URL"` |  |
| extraEnvVars[0].value | string | `"https://${org-subdomain}portal.dev.local:8443/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql"` |  |
| extraEnvVars[1].name | string | `"PLATFORM_MESH_PORTAL_CONTEXT_IAM_SERVICE_API_URL"` |  |
| extraEnvVars[1].value | string | `"https://portal.dev.local:8443/iam/query"` |  |
| extraEnvVars[2].name | string | `"PLATFORM_MESH_PORTAL_CONTEXT_IAM_ENTITY_CONFIG"` |  |
| extraEnvVars[2].value | string | `"{\"account\":{\"contextProperty\":\"entityId\"}}"` |  |
| featureToggles | string | `"enableSessionAutoRefresh=true"` |  |
| frontendPort | int | `8000` |  |
| health.liveness.path | string | `"/rest/health"` |  |
| health.port | int | `9000` |  |
| health.readiness.path | string | `"/rest/health"` |  |
| health.startup.path | string | `"/rest/health"` |  |
| http.protocol | string | `"http"` |  |
| image.name | string | `"ghcr.io/platform-mesh/portal"` |  |
| image.pullPolicyOverride | string | `"IfNotPresent"` |  |
| importContent | bool | `false` |  |
| kubeconfigSecret | string | `""` |  |
| trust.platform-mesh.authDomain | string | `"http://localhost:8000/keycloak/realms/platform-mesh/protocol/openid-connect/auth"` |  |
| trust.platform-mesh.baseDomains | string | `"localhost"` |  |
| trust.platform-mesh.contentConfigurationValidatorApiUrl | string | `"http://platform-mesh-extension-manager-operator-server.platform-mesh-system.svc.cluster.local:8088/validate"` |  |
| trust.platform-mesh.discoveryEndpoint | string | `""` |  |
| trust.platform-mesh.loginAudience | string | `"platform-mesh"` |  |
| trust.platform-mesh.oidcClientSecretName | string | `"platform-mesh-client"` |  |
| trust.platform-mesh.secretKeyRef | string | `"attribute.client_secret"` |  |
| trust.platform-mesh.tokenUrl | string | `"http://platform-mesh-keycloak/keycloak/realms/platform-mesh/protocol/openid-connect/token"` |  |
| validWebcomponentUrls | string | `".?"` |  |
| virtualService.hosts[0] | string | `"*"` |  |

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
