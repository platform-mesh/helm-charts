# kubernetes-graphql-gateway

Basic helm chart that contains listener and gateway

# Local setup

You can install helm chart locally, but you must provide kubeconfig:
```
kubeConfig:
  createSecret: true # the content below must be stored in the secret, set to true to create it
  enabled: true
  content: |-
    apiVersion: v1
```
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crds.enabled | bool | `false` |  |
| deployment.maxSurge | int | `5` |  |
| deployment.maxUnavailable | int | `0` |  |
| deployment.replicas | int | `1` |  |
| deployment.revisionHistoryLimit | int | `3` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| gateway.extraArgs | list | `[]` |  |
| gateway.graphiql | bool | `true` |  |
| gateway.healthCheck.enabled | bool | `true` |  |
| gateway.healthCheck.port | int | `8080` |  |
| gateway.introspectionAuthentication | bool | `true` |  |
| gateway.logLevel | string | `"trace"` |  |
| gateway.metricsPort | int | `8081` |  |
| gateway.port | int | `8080` |  |
| gateway.resources.limits.memory | string | `"1200Mi"` |  |
| gateway.resources.requests.cpu | string | `"250m"` |  |
| gateway.resources.requests.memory | string | `"1000Mi"` |  |
| gateway.shouldImpersonate | bool | `false` |  |
| gateway.usernameClaim | string | `"email"` |  |
| gatewayApi.httpRoute | object | `{"corsFilters":[{"extensionRef":{"group":"traefik.io","kind":"Middleware","name":"cors-header"},"type":"ExtensionRef"}],"enabled":true,"filters":[{"type":"URLRewrite","urlRewrite":{"path":{"replacePrefixMatch":"/api/clusters/","type":"ReplacePrefixMatch"}}}],"hostnames":["portal.localhost","*.portal.localhost"],"parentRefs":[{"name":"k8sapi-gateway"}],"pathPrefix":"/gateway/api/clusters/"}` | configuration for the HTTPRoute resource |
| gatewayApi.httpRoute.corsFilters | list | `[{"extensionRef":{"group":"traefik.io","kind":"Middleware","name":"cors-header"},"type":"ExtensionRef"}]` | CORS filter referencing traefik middleware (used when traefik.enabled=true) |
| gatewayApi.httpRoute.filters | list | `[{"type":"URLRewrite","urlRewrite":{"path":{"replacePrefixMatch":"/api/clusters/","type":"ReplacePrefixMatch"}}}]` | list of HTTPRoute filters (default: URLRewrite only, no CORS) |
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
| hostAliases.enabled | bool | `false` |  |
| image.name | string | `"ghcr.io/platform-mesh/kubernetes-graphql-gateway"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| kcp.enabled | bool | `true` |  |
| kubeConfig.createSecret | bool | `false` |  |
| kubeConfig.enabled | bool | `false` | Allows the mounting of an external kubeconfig. If the kubeconfig is set, it is expected that the service account, that is used, is not connected to this chart and the rbac resources will not be generated. |
| kubeConfig.path | string | `"/app/kubeconfig/kubeconfig"` |  |
| kubeConfig.secretName | string | `"kcp-root-kubeconfig"` |  |
| listener.additionalPathAnnotationKey | string | `"kcp.io/path"` |  |
| listener.anchorResource | string | `"object.metadata.name.startsWith(\"core.platform-mesh.io\")"` | CEL expression for anchor resource matching |
| listener.apiExportEndpointSliceName | string | `"core.platform-mesh.io"` |  |
| listener.extraArgs | list | `[]` |  |
| listener.grpcPort | int | `50051` |  |
| listener.healthCheck.enabled | bool | `false` |  |
| listener.healthCheck.port | int | `3390` |  |
| listener.metricsPort | int | `8091` |  |
| listener.multiclusterRuntimeProvider | string | `"kcp"` | Multicluster runtime provider: "kcp" or "kubernetes" |
| listener.port | int | `8090` |  |
| listener.reconcilerGvr | string | `"apibindings.v1alpha2.apis.kcp.io"` | GroupVersionResource for the reconciler to watch |
| listener.resources.limits.memory | string | `"600Mi"` |  |
| listener.resources.requests.cpu | string | `"250m"` |  |
| listener.resources.requests.memory | string | `"500Mi"` |  |
| listener.virtualWorkspacesConfig.configMapName | string | `"virtual-workspaces-config"` |  |
| listener.virtualWorkspacesConfig.content.virtualWorkspaces | list | `[]` |  |
| listener.virtualWorkspacesConfig.enabled | bool | `false` |  |
| listener.virtualWorkspacesConfig.path | string | `"/app/config/virtual-workspaces.yaml"` |  |
| listener.workspaceSchemaKubeconfigOverride | string | `""` |  |
| rbac.createServiceAccountRules | bool | `false` | Enables RBAC rules for service accounts (get, list, watch on serviceaccounts and serviceaccounts/token). Uses namespace-scoped Roles when serviceAccounts list is provided. |
| rbac.serviceAccounts | list | [] | List of service accounts with name and namespace to allow access to. Creates a Role and RoleBinding per namespace. Example: serviceAccounts:   - name: my-service-account     namespace: my-namespace   - name: another-sa     namespace: another-namespace |
| schemaHandler | object | `{"schemasDir":"/app/schemas","sharedVolume":{"accessMode":"ReadWriteOnce","size":"500Mi","storageClassName":""},"type":"file"}` | Schema handler type: "grpc" or "file" |
| schemaHandler.schemasDir | string | `"/app/schemas"` | Directory path for schema files (used when type is "file") |
| schemaHandler.sharedVolume | object | `{"accessMode":"ReadWriteOnce","size":"500Mi","storageClassName":""}` | Shared volume configuration (used when type is "file") |
| sentry.environment | string | `"dev"` |  |
| tracing.enabled | bool | `true` |  |
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
