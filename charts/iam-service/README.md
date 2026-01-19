# iam-service

A Helm chart for Kubernetes

## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| caSecret | string | `""` |  |
| cors.enabled | bool | `false` |  |
| exposure.hostnames | list | `["portal.localhost","*.portal.localhost"]` | hostnames to be used for exposure |
| gatewayApi.httpRoute.corsFilters[0].extensionRef.group | string | `"traefik.io"` |  |
| gatewayApi.httpRoute.corsFilters[0].extensionRef.kind | string | `"Middleware"` |  |
| gatewayApi.httpRoute.corsFilters[0].extensionRef.name | string | `"cors-header"` |  |
| gatewayApi.httpRoute.corsFilters[0].type | string | `"ExtensionRef"` |  |
| gatewayApi.httpRoute.filters[0].type | string | `"URLRewrite"` |  |
| gatewayApi.httpRoute.filters[0].urlRewrite.path.replacePrefixMatch | string | `"/graphql"` |  |
| gatewayApi.httpRoute.filters[0].urlRewrite.path.type | string | `"ReplacePrefixMatch"` |  |
| gatewayApi.httpRoute.parentRefs[0].name | string | `"k8sapi-gateway"` |  |
| gatewayApi.httpRoute.parentRefs[0].sectionName | string | `"websecure"` |  |
| gatewayApi.httpRoute.parentRefs[1].name | string | `"k8sapi-gateway"` |  |
| gatewayApi.httpRoute.parentRefs[1].sectionName | string | `"websecure-wildcard-portal-localhost"` |  |
| gatewayApi.httpRoute.pathPrefix | string | `"/iam/graphql"` |  |
| health.port | int | `8080` |  |
| hostAliases.enabled | bool | `false` |  |
| hostAliases.items[0].hostnames[0] | string | `"portal.localhost"` |  |
| hostAliases.items[0].hostnames[1] | string | `"localhost"` |  |
| hostAliases.items[0].ip | string | `"10.96.188.4"` |  |
| image.name | string | `"ghcr.io/platform-mesh/iam-service"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| imagePullSecret | string | `"github"` |  |
| jwt.userIdClaim | string | `"email"` |  |
| kcp.kubeconfig.secretName | string | `"iam-service-kubeconfig"` |  |
| keycloak.baseUrl | string | `"https://portal.localhost:8443/keycloak"` |  |
| keycloak.client.id | string | `"iam"` |  |
| keycloak.client.secret.key | string | `"attribute.client_secret"` |  |
| keycloak.client.secret.name | string | `"iam-client-secret"` |  |
| port | int | `8080` |  |
| roles.raw.roles[0].groupResource | string | `"core.platform-mesh.io/Account"` |  |
| roles.raw.roles[0].roles[0].description | string | `"Full access to all resources within the account."` |  |
| roles.raw.roles[0].roles[0].displayName | string | `"Owner"` |  |
| roles.raw.roles[0].roles[0].id | string | `"owner"` |  |
| roles.raw.roles[0].roles[1].description | string | `"Limited access to resources within the account. Can view and interact with resources but cannot administrate them."` |  |
| roles.raw.roles[0].roles[1].displayName | string | `"Member"` |  |
| roles.raw.roles[0].roles[1].id | string | `"member"` |  |
| roles.raw.roles[1].groupResource | string | `"Namespace"` |  |
| roles.raw.roles[1].roles[0].description | string | `"Full access to all resources within the account."` |  |
| roles.raw.roles[1].roles[0].displayName | string | `"Owner"` |  |
| roles.raw.roles[1].roles[0].id | string | `"owner"` |  |
| roles.raw.roles[1].roles[1].description | string | `"Limited access to resources within the account. Can view and interact with resources but cannot administrate them."` |  |
| roles.raw.roles[1].roles[1].displayName | string | `"Member"` |  |
| roles.raw.roles[1].roles[1].id | string | `"member"` |  |

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
