# infra

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crossplane.enabled | bool | `true` |  |
| externalSecrets.enabled | bool | `false` |  |
| hostAliases.enabled | bool | `false` |  |
| hostAliases.entries[0].hostnames[0] | string | `"kcp.api.portal.dev.local"` |  |
| hostAliases.entries[0].hostnames[1] | string | `"portal.dev.local"` |  |
| hostAliases.entries[0].ip | string | `"10.96.188.4"` |  |
| istio.enabled | bool | `true` |  |
| istio.gateway.annotations | object | `{}` |  |
| istio.gateway.apiVersion | string | `"networking.istio.io/v1"` |  |
| istio.gateway.name | string | `"gateway"` |  |
| istio.gateway.selector.istio | string | `"gateway"` |  |
| istio.main.gateway.hosts[0] | string | `"*"` |  |
| istio.main.gateway.name | string | `"http"` |  |
| istio.main.gateway.port | int | `8000` |  |
| istio.main.gateway.protocol | string | `"HTTP"` |  |
| istio.networking.apiVersion | string | `"networking.istio.io/v1"` | The istio apiVersion used for networking resources in this chart eg. networking.istio.io/v1, networking.istio.io/v1beta1 |
| istio.passThrough.gateway.enabled | bool | `false` |  |
| istio.serviceEntries.https.enabled | bool | `false` | A toggle to enable the service entries for external https communication |
| istio.serviceEntries.https.hosts | list | `[]` | The list of hosts to be added to the service entry |
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
| kcp.external.hostname | string | `"kcp.api.portal.dev.local"` |  |
| kcp.external.port | int | `8443` |  |
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
| kcp.frontProxy.clusterIP | string | `""` |  |
| kcp.frontProxy.extraArgs[0] | string | `"--feature-gates=WorkspaceAuthentication=true"` |  |
| kcp.frontProxy.name | string | `"frontproxy"` |  |
| kcp.frontProxy.port | int | `8443` |  |
| kcp.frontProxy.replicas | int | `1` |  |
| kcp.image.tag | string | `""` |  |
| kcp.istio.hosts[0] | string | `"kcp.api.portal.dev.local"` |  |
| kcp.namespace | string | `"platform-mesh-system"` |  |
| kcp.oidc.caFileRef.key | string | `"tls.crt"` |  |
| kcp.oidc.caFileRef.name | string | `"domain-certificate-ca"` |  |
| kcp.oidc.clientID | string | `""` |  |
| kcp.oidc.enabled | bool | `false` |  |
| kcp.oidc.groupsClaim | string | `"groups"` |  |
| kcp.oidc.issuerUrl | string | `""` |  |
| kcp.oidc.usernameClaim | string | `"email"` |  |
| kcp.rootShard.extraArgs[0] | string | `"--feature-gates=WorkspaceAuthentication=true"` |  |
| kcp.rootShard.replicas | int | `1` |  |
| kcp.webhook.authorizationWebhookSecretName | string | `"kcp-webhook-secret"` |  |
| kcp.webhook.caData | string | `""` |  |
| kcp.webhook.enabled | bool | `true` |  |
| kcp.webhook.port | int | `9443` |  |
| kcp.webhook.server | string | `"https://rebac-authz-webhook.platform-mesh-system.svc.cluster.local:9443/authz"` |  |
| keycloak.crossplane.clients.welcome.name | string | `"Welcome"` | name of the client |
| keycloak.crossplane.clients.welcome.validRedirectUris | list | `["http://localhost:8000/callback*","http://localhost:4300/callback*"]` | valid redirect uris for the client |
| keycloak.crossplane.clients.welcome.validRedirectUris[0] | string | `"http://localhost:8000/callback*"` | keycloak callback url |
| keycloak.crossplane.enabled | bool | `true` | toggle to enable/disable crossplane |
| keycloak.crossplane.identityProviders | object | `{}` |  |
| keycloak.crossplane.providerConfig | object | `{"name":"keycloak-provider-config","namespace":"platform-mesh-system"}` | crossplane provider config |
| keycloak.crossplane.providerConfig.name | string | `"keycloak-provider-config"` | name of the client |
| keycloak.crossplane.providerConfig.namespace | string | `"platform-mesh-system"` | client namespace |
| keycloak.crossplane.realm | object | `{"accessTokenLifespan":"8h","displayName":"welcome","name":"welcome","registrationAllowed":true,"smtpServer":[{"from":"noreply@portal.dev.local","host":"mailpit.platform-mesh-system.svc.cluster.local","port":"1025"}],"verifyEmail":true}` | crossplane realm config |
| keycloak.crossplane.realm.accessTokenLifespan | string | `"8h"` | realm access token lifespan |
| keycloak.crossplane.realm.displayName | string | `"welcome"` | realm display name |
| keycloak.crossplane.realm.name | string | `"welcome"` | realm name |
| keycloak.crossplane.realm.registrationAllowed | bool | `true` | realm registration allowed |
| keycloak.crossplane.realm.verifyEmail | bool | `true` | realm email verification |
| keycloak.crossplane.trustedAudiences | list | `[]` |  |
| keycloak.domain | object | `{"name":"platform-mesh.io","pathPrefix":"/keycloak"}` | domain configuration |
| keycloak.domain.name | string | `"platform-mesh.io"` | domain name |
| keycloak.domain.pathPrefix | string | `"/keycloak"` | path prefix |
| keycloak.istio.https.port | int | `8443` |  |
| keycloak.istio.virtualservice.hosts | list | `["*"]` | istio virtual service hosts |
| keycloak.keycloakConfig.admin | object | `{"password":{"valueFrom":{"secretKeyRef":{"key":"secret","name":"keycloak-admin"}}},"username":{"value":"keycloak-admin"}}` | admin user configuration |
| keycloak.keycloakConfig.admin.password | object | `{"valueFrom":{"secretKeyRef":{"key":"secret","name":"keycloak-admin"}}}` | admin password |
| keycloak.keycloakConfig.admin.password.valueFrom.secretKeyRef.key | string | `"secret"` | key of the password in the secret |
| keycloak.keycloakConfig.admin.password.valueFrom.secretKeyRef.name | string | `"keycloak-admin"` | name of the secret containing the password |
| keycloak.keycloakConfig.admin.username.value | string | `"keycloak-admin"` | username |
| keycloak.keycloakConfig.client | object | `{"name":"welcome","targetSecret":{"name":"portal-client-secret-welcome","namespace":"platform-mesh-system"},"tokenLifespan":3600}` | client configuration |
| keycloak.keycloakConfig.client.name | string | `"welcome"` | client name |
| keycloak.keycloakConfig.client.targetSecret | object | `{"name":"portal-client-secret-welcome","namespace":"platform-mesh-system"}` | target secret options |
| keycloak.keycloakConfig.client.targetSecret.name | string | `"portal-client-secret-welcome"` | secret name |
| keycloak.keycloakConfig.client.targetSecret.namespace | string | `"platform-mesh-system"` | secret namespace |
| keycloak.keycloakConfig.client.tokenLifespan | int | `3600` | token lifespan |
| keycloak.keycloakConfig.realm | object | `{"name":"master"}` | realm configuration |
| keycloak.keycloakConfig.realm.name | string | `"master"` | realm name |
| keycloak.keycloakConfig.redirectUrls | list | `["http://localhost:8000/callback*"]` | redirect urls |
| keycloak.keycloakConfig.url | string | `"http://keycloak.platform-mesh-system.svc.cluster.local/keycloak"` | url of the keycloak server |
| keycloak.keycloakConfig.userRegistration.enabled | bool | `true` | toggle to enable/disable user registration |
| keycloak.service | object | `{"name":"keycloak","port":80}` | service configuration |
| keycloak.service.name | string | `"keycloak"` | service name |
| keycloak.service.port | int | `80` | service port |
| mailpit.domain.pathPrefix | string | `"/mailpit"` | path prefix |
| mailpit.enabled | bool | `false` |  |
| mailpit.image.tag | string | `"v1.27.9"` |  |
| mailpit.istio.virtualservice.hosts | list | `["*"]` | istio virtual service hosts |
| openfga.rbac.requestPrincipals | list | `[]` |  |
| openfga.rbac.writePrincipals[0] | string | `"cluster.local/ns/platform-mesh-system/sa/iam-service"` |  |
| openfga.rbac.writePrincipals[1] | string | `"cluster.local/ns/platform-mesh-system/sa/iam-service-dataloader-sa"` |  |
| openfga.rbac.writePrincipals[2] | string | `"cluster.local/ns/platform-mesh-system/sa/security-operator"` |  |
| openfga.rbac.writePrincipals[3] | string | `"cluster.local/ns/platform-mesh-system/sa/account-operator"` |  |

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
