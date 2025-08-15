# portal

Helm Chart for the Platform Mesh Portal

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/openmfp/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/openmfp/helm-charts/tree/main/charts/common)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| baseDomains[0] | string | `"localhost"` | base domains for VirtualService |
| cookieDomain | string | `"localhost"` | cookie domain |
| deployment.hostAliases | list | `[]` |  |
| developmentLandcsape | string | `"true"` | development landscape toggle |
| environment | string | `"local"` | environment |
| featureToggles | string | `"enableSessionAutoRefresh=true"` |  |
| frontendPort | int | `8000` | frontend port |
| health | object | `{"liveness":{"path":"/rest/health"},"port":8080,"readiness":{"path":"/rest/health"},"startup":{"path":"/rest/health"}}` | A way to provide additional experimental environment variables extraEnvVars:  - name: DEMO_PORTAL_CONTEXT_CRD_GATEWAY_API_URL    value: https://${org-subdomain}portal.dev.local:8443/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql  - name: DEMO_PORTAL_CONTEXT_IAM_SERVICE_API_URL    value: https://portal.dev.local:8443/iam/query  - name: DEMO_PORTAL_CONTEXT_IAM_ENTITY_CONFIG    value: >-      {"account":{"contextProperty":"entityId"}} trust:  demo:    # -- base domains    baseDomains: "localhost"    # -- discovery endpoint. If specified (different than ""), authDomain and tokenUrl are not required    discoveryEndpoint: ""    # -- auth domain (if discoveryEndpoint is not specified)    authDomain: http://localhost:8000/keycloak/realms/platform-mesh/protocol/openid-connect/auth    # -- token url (if discoveryEndpoint is not specified)    tokenUrl: http://keycloak/keycloak/realms/platform-mesh/protocol/openid-connect/token    # -- oidc client secret name    oidcClientSecretName: platform-mesh-client    # -- login audience    loginAudience: platform-mesh    # -- secret key reference    secretKeyRef: attribute.client_secret    # -- ContentConfiguration validator api url    contentConfigurationValidatorApiUrl: http://extension-manager-operator-server.platform-mesh-system.svc.cluster.local:8088/validate |
| health.liveness.path | string | `"/rest/health"` | path used for the liveness probe |
| health.port | int | `8080` | health port to be used by probes |
| health.readiness.path | string | `"/rest/health"` | path used for the readiness probe |
| health.startup.path | string | `"/rest/health"` | path used for the startup probe |
| http.protocol | string | `"http"` | protocol |
| image.name | string | `"ghcr.io/platform-mesh/portal"` |  |
| image.pullPolicyOverride | string | `"IfNotPresent"` |  |
| importContent | bool | `false` | import content toggle |
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
