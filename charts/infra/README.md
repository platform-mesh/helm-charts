# infra

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| kcp.auth.adminCert.enabled | bool | `true` |  |
| kcp.auth.adminCert.privateKey.algorithm | string | `"RSA"` |  |
| kcp.auth.adminCert.privateKey.size | int | `2048` |  |
| kcp.auth.adminCert.subject.organizations[0] | string | `"system:kcp:admin"` |  |
| kcp.etcd.backup.compression.enabled | bool | `false` |  |
| kcp.etcd.backup.compression.policy | string | `"gzip"` |  |
| kcp.etcd.backup.deltaSnapshotMemoryLimit | string | `"1Gi"` |  |
| kcp.etcd.backup.deltaSnapshotPeriod | string | `"300s"` |  |
| kcp.etcd.backup.fullSnapshotSchedule | string | `"0 */24 * * *"` |  |
| kcp.etcd.backup.garbageCollectionPeriod | string | `"43200s"` |  |
| kcp.etcd.backup.garbageCollectionPolicy | string | `"Exponential"` |  |
| kcp.etcd.backup.leaderElection.etcdConnectionTimeout | string | `"5s"` |  |
| kcp.etcd.backup.leaderElection.reelectionPeriod | string | `"5s"` |  |
| kcp.etcd.backup.port | int | `8080` |  |
| kcp.etcd.backup.resources.limits.cpu | string | `"200m"` |  |
| kcp.etcd.backup.resources.limits.memory | string | `"1Gi"` |  |
| kcp.etcd.backup.resources.requests.cpu | string | `"23m"` |  |
| kcp.etcd.backup.resources.requests.memory | string | `"128Mi"` |  |
| kcp.etcd.defragmentationSchedule | string | `"0 */24 * * *"` |  |
| kcp.etcd.name | string | `"etcd-kcp"` |  |
| kcp.etcd.quota | string | `"8Gi"` |  |
| kcp.etcd.replicas | int | `1` |  |
| kcp.etcd.resources.limits.cpu | string | `"500m"` |  |
| kcp.etcd.resources.limits.memory | string | `"1Gi"` |  |
| kcp.etcd.resources.requests.cpu | string | `"100m"` |  |
| kcp.etcd.resources.requests.memory | string | `"200Mi"` |  |
| kcp.etcd.serverPort | int | `2380` |  |
| kcp.etcd.service.name | string | `"etcd-kcp-client"` |  |
| kcp.etcd.service.port | int | `2379` |  |
| kcp.etcd.sharedConfig.autoCompactionMode | string | `"periodic"` |  |
| kcp.etcd.sharedConfig.autoCompactionRetention | string | `"30m"` |  |
| kcp.frontProxy.additionalPathMappings[0].backend | string | `"https://virtual-workspaces.platform-mesh-system:8443"` |  |
| kcp.frontProxy.additionalPathMappings[0].backend_server_ca | string | `"/etc/kcp/tls/ca/tls.crt"` |  |
| kcp.frontProxy.additionalPathMappings[0].path | string | `"/services/contentconfigurations"` |  |
| kcp.frontProxy.additionalPathMappings[0].proxy_client_cert | string | `"/etc/kcp-front-proxy/requestheader-client/tls.crt"` |  |
| kcp.frontProxy.additionalPathMappings[0].proxy_client_key | string | `"/etc/kcp-front-proxy/requestheader-client/tls.key"` |  |
| kcp.frontProxy.additionalPathMappings[1].backend | string | `"https://virtual-workspaces.platform-mesh-system:8443"` |  |
| kcp.frontProxy.additionalPathMappings[1].backend_server_ca | string | `"/etc/kcp/tls/ca/tls.crt"` |  |
| kcp.frontProxy.additionalPathMappings[1].path | string | `"/services/marketplace"` |  |
| kcp.frontProxy.additionalPathMappings[1].proxy_client_cert | string | `"/etc/kcp-front-proxy/requestheader-client/tls.crt"` |  |
| kcp.frontProxy.additionalPathMappings[1].proxy_client_key | string | `"/etc/kcp-front-proxy/requestheader-client/tls.key"` |  |
| kcp.namespace | string | `"kcp-system"` |  |
| kcp.oidc.clientID | string | `"default"` |  |
| kcp.oidc.enabled | bool | `true` |  |
| kcp.oidc.groupsClaim | string | `"groups"` |  |
| kcp.oidc.issuerUrl | string | `"https://portal.dev.local:8443/keycloak/realms/default"` |  |
| kcp.oidc.usernameClaim | string | `"email"` |  |

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
