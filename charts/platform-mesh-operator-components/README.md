# platform-mesh-operator-components

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fluxCD.kubeConfig.enabled | bool | `false` | If set, all created FluxCD resources will deploy to a remote cluster using this kubeconfig. |
| fluxCD.kubeConfig.secretRef.key | string | `"kubeconfig"` |  |
| fluxCD.kubeConfig.secretRef.name | string | `"platform-mesh-kubeconfig"` | name of the secret containing the kubeconfig |
| iamWebhookCA | string | `nil` |  |
| ocm.component.create | bool | `true` |  |
| ocm.component.name | string | `"platform-mesh"` |  |
| ocm.interval | string | `"3m"` |  |
| ocm.referencePath | list | `[]` |  |
| ocm.repo.create | bool | `true` |  |
| ocm.repo.name | string | `"platform-mesh"` |  |
| ocm.skipVerify | bool | `true` |  |
| port | int | `443` |  |
| protocol | string | `"https"` |  |
| services.account-operator.enabled | bool | `true` |  |
| services.account-operator.imageResources | list | `[{"annotations":{"artifact":"image","for":"account-operator","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.account-operator.values.crds.enabled | bool | `false` |  |
| services.account-operator.values.kcp.apiExportEndpointSliceName | string | `""` |  |
| services.account-operator.values.kcp.enabled | bool | `true` |  |
| services.account-operator.values.kubeconfigSecret | string | `"account-operator-kubeconfig"` |  |
| services.account-operator.values.log.level | string | `"debug"` |  |
| services.account-operator.values.subroutines.fga.grpcAddr | string | `"openfga:8081"` |  |
| services.account-operator.values.tracing.collector.host | string | `"observability-opentelemetry-collector.observability.svc.cluster.local:4317"` |  |
| services.account-operator.values.tracing.enabled | bool | `false` |  |
| services.extension-manager-operator.enabled | bool | `true` |  |
| services.extension-manager-operator.imageResources | list | `[{"annotations":{"artifact":"image","for":"extension-manager-operator","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.extension-manager-operator.values.crds.enabled | bool | `false` |  |
| services.extension-manager-operator.values.kcp.enabled | bool | `true` |  |
| services.extension-manager-operator.values.kcp.kubeconfigSecret | string | `"extension-manager-operator-kubeconfig"` |  |
| services.extension-manager-operator.values.tracing.collector.host | string | `"observability-opentelemetry-collector.observability.svc.cluster.local:4317"` |  |
| services.extension-manager-operator.values.tracing.enabled | bool | `false` |  |
| services.iam-service.enabled | bool | `true` | Enable IAM Service |
| services.iam-service.imageResources | list | `[{"annotations":{"artifact":"image","for":"iam-service","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.iam-service.values.caSecret | string | `"domain-certificate-ca"` |  |
| services.iam-ui.enabled | bool | `true` | Enable IAM UI |
| services.iam-ui.imageResources | list | `[{"annotations":{"artifact":"image","for":"iam-ui","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.infra.dependsOn[0].name | string | `"kcp-operator"` |  |
| services.infra.dependsOn[0].namespace | string | `"default"` |  |
| services.infra.enabled | bool | `true` |  |
| services.infra.imageResources | list | `[{"annotations":{"artifact":"image","for":"infra","path":"kcp.image.tag","repo":"oci"},"name":"kcp-image","referencePath":[{"name":"kcp"}],"resource":"image"}]` | Allow the configuration of additional ocm resources |
| services.infra.values.gatewayApi.enabled | bool | `true` |  |
| services.infra.values.istio.main.gateway.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.infra.values.istio.main.gateway.hosts[1] | string | `"*.{{ .Values.baseDomain }}"` |  |
| services.infra.values.istio.main.gateway.name | string | `"https"` |  |
| services.infra.values.istio.main.gateway.port | string | `"{{ .Values.port }}"` |  |
| services.infra.values.istio.main.gateway.protocol | string | `"HTTPS"` |  |
| services.infra.values.istio.main.gateway.tls.credentialName | string | `"domain-certificate"` |  |
| services.infra.values.istio.main.gateway.tls.minProtocolVersion | string | `"TLSV1_2"` |  |
| services.infra.values.istio.main.gateway.tls.mode | string | `"SIMPLE"` |  |
| services.infra.values.istio.passThrough.gateway.enabled | bool | `true` |  |
| services.infra.values.istio.passThrough.gateway.hosts[0] | string | `"kcp.api.{{ .Values.baseDomain }}"` |  |
| services.infra.values.istio.passThrough.gateway.name | string | `"pass-https"` |  |
| services.infra.values.istio.passThrough.gateway.port | string | `"{{ .Values.port }}"` |  |
| services.infra.values.istio.passThrough.gateway.protocol | string | `"HTTPS"` |  |
| services.infra.values.kcp.image.tag | string | `"v0.29.0"` |  |
| services.infra.values.kcp.rootShard.extraArgs[0] | string | `"--feature-gates=WorkspaceAuthentication=true"` |  |
| services.infra.values.kcp.rootShard.extraArgs[1] | string | `"--shard-virtual-workspace-url=https://localhost:8443"` |  |
| services.infra.values.kcp.webhook.enabled | bool | `true` |  |
| services.infra.values.keycloak.istio.virtualservice.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.keycloak.enabled | bool | `true` |  |
| services.keycloak.imageResources[0].annotations.artifact | string | `"image"` |  |
| services.keycloak.imageResources[0].annotations.for | string | `"keycloak"` |  |
| services.keycloak.imageResources[0].annotations.repo | string | `"oci"` |  |
| services.keycloak.imageResources[0].name | string | `"keycloak-image"` |  |
| services.keycloak.imageResources[1].annotations.artifact | string | `"image"` |  |
| services.keycloak.imageResources[1].annotations.for | string | `"keycloak"` |  |
| services.keycloak.imageResources[1].annotations.path | string | `"postgresql.image.tag"` |  |
| services.keycloak.imageResources[1].annotations.repo | string | `"oci"` |  |
| services.keycloak.imageResources[1].name | string | `"keycloak-postgresql-image"` |  |
| services.keycloak.imageResources[1].resource | string | `"postgresql-image"` |  |
| services.keycloak.values.auth.adminUser | string | `"keycloak-admin"` | keycloak admin user |
| services.keycloak.values.auth.existingSecret | string | `"keycloak-admin"` | keycloak admin secret |
| services.keycloak.values.auth.passwordSecretKey | string | `"secret"` | keycloak admin secret key |
| services.keycloak.values.extraEnvVars | list | `[{"name":"JAVA_OPTS_APPEND","value":"-Djgroups.dns.query=keycloak-headless.platform-mesh-system.svc.cluster.local"},{"name":"KC_PROXY_HEADERS","value":"xforwarded"},{"name":"KC_HOSTNAME_STRICT","value":"false"}]` | keycloak environment variables (raw) For Arm64 arch (especially Apple M4), add -XX:UseSVE=0 to JAVA_OPTS_APPEND |
| services.keycloak.values.global.security.allowInsecureImages | bool | `true` |  |
| services.keycloak.values.httpRelativePath | string | `"/keycloak/"` | keycloak http relative path |
| services.keycloak.values.image.registry | string | `"ghcr.io/platform-mesh"` |  |
| services.keycloak.values.image.repository | string | `"upstream-images/keycloak"` |  |
| services.keycloak.values.postgresql | object | `{"auth":{"existingSecret":"","secretKeys":{"adminPasswordKey":"password","userPasswordKey":"password"},"username":"keycloak"},"image":{"registry":"ghcr.io/platform-mesh","repository":"upstream-images/postgresql"},"nameOverride":"postgresql-keycloak","primary":{"resourcesPreset":"none"}}` | configuration for the postgresql sub-chart |
| services.keycloak.values.postgresql.auth | object | `{"existingSecret":"","secretKeys":{"adminPasswordKey":"password","userPasswordKey":"password"},"username":"keycloak"}` | authorization configuration |
| services.keycloak.values.postgresql.auth.existingSecret | string | `""` | existing secret name |
| services.keycloak.values.postgresql.auth.secretKeys.adminPasswordKey | string | `"password"` | admin password key |
| services.keycloak.values.postgresql.auth.secretKeys.userPasswordKey | string | `"password"` | user password key |
| services.keycloak.values.postgresql.auth.username | string | `"keycloak"` | postgresql username |
| services.keycloak.values.postgresql.nameOverride | string | `"postgresql-keycloak"` | postgresql name override |
| services.keycloak.values.postgresql.primary.resourcesPreset | string | `"none"` | primary postgresql resources preset |
| services.keycloak.values.resources.limits.cpu | string | `"2"` |  |
| services.keycloak.values.resources.limits.ephemeral-storage | string | `"2Gi"` |  |
| services.keycloak.values.resources.limits.memory | string | `"2Gi"` |  |
| services.keycloak.values.resources.requests.cpu | string | `"750m"` |  |
| services.keycloak.values.resources.requests.ephemeral-storage | string | `"50Mi"` |  |
| services.keycloak.values.resources.requests.memory | string | `"1Gi"` |  |
| services.kubernetes-graphql-gateway.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.imageResources | list | `[{"annotations":{"artifact":"image","for":"kubernetes-graphql-gateway","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.kubernetes-graphql-gateway.values.cors.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.gatewayApi.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.kubeConfig.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.kubeConfig.secretName | string | `"kubernetes-grapqhl-gateway-kubeconfig"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[0].kubeconfig | string | `"/app/kubeconfig/kubeconfig"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[0].name | string | `"contentconfigurations"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[0].url | string | `"https://frontproxy-front-proxy.platform-mesh-system:6443/services/contentconfigurations"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[1].kubeconfig | string | `"/app/kubeconfig/kubeconfig"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[1].name | string | `"marketplace"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[1].url | string | `"https://frontproxy-front-proxy.platform-mesh-system:6443/services/marketplace"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.tracing.enabled | bool | `false` |  |
| services.kubernetes-graphql-gateway.values.trust.default.audience | string | `"default"` |  |
| services.kubernetes-graphql-gateway.values.trust.default.jwksUrl | string | `"http://keycloak-headless.platform-mesh-system:8080/keycloak/realms/default/protocol/openid-connect/certs"` |  |
| services.kubernetes-graphql-gateway.values.trust.default.trustedIssuer | string | `"https://{{ .Values.baseDomainPort }}/keycloak/realms/default"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.hosts[1] | string | `"*.{{ .Values.baseDomain }}"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowHeaders[0] | string | `"*"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowMethods[0] | string | `"GET"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowMethods[1] | string | `"POST"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowOrigins[0].regex | string | `".*"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].name | string | `"default"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.pathPrefix | string | `"/api/kubernetes-graphql-gateway/"` |  |
| services.marketplace-ui.enabled | bool | `false` |  |
| services.marketplace-ui.imageResources | list | `[{"annotations":{"artifact":"image","for":"marketplace-ui","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.marketplace-ui.values.gatewayApi.enabled | bool | `true` |  |
| services.marketplace-ui.values.istio.enabled | bool | `false` |  |
| services.observability.enabled | bool | `false` |  |
| services.observability.targetNamespace | string | `"observability"` |  |
| services.observability.values.istio.grafana.virtualService.hosts[0] | string | `"grafana.{{ .Values.baseDomain }}"` |  |
| services.observability.values.istio.tracing.enabled | bool | `false` |  |
| services.observability.values.opentelemetry-collector.ports.metrics.enabled | bool | `true` |  |
| services.observability.values.opentelemetry-collector.service.type | string | `"ClusterIP"` |  |
| services.openfga.enabled | bool | `true` |  |
| services.openfga.helmRepo | bool | `true` |  |
| services.openfga.imageResources | list | `[{"annotations":{"artifact":"image","for":"openfga","repo":"oci"},"name":"openfga-image"},{"annotations":{"artifact":"image","for":"openfga","path":"postgresql.image.tag","repo":"oci"},"name":"openfga-postgresql-image","resource":"postgresql-image"}]` | Allow the configuration of additional ocm resources |
| services.openfga.values.autoscaling.enabled | bool | `false` |  |
| services.openfga.values.checkQueryCache.enabled | bool | `true` |  |
| services.openfga.values.checkQueryCache.limit | int | `10000` |  |
| services.openfga.values.checkQueryCache.ttl | string | `"10s"` |  |
| services.openfga.values.datastore.applyMigrations | bool | `true` |  |
| services.openfga.values.datastore.engine | string | `"postgres"` |  |
| services.openfga.values.datastore.maxOpenConns | int | `30` |  |
| services.openfga.values.datastore.migrationType | string | `"initContainer"` |  |
| services.openfga.values.datastore.migrations.image.pullPolicy | string | `"Always"` |  |
| services.openfga.values.datastore.migrations.image.repository | string | `"groundnuty/k8s-wait-for"` |  |
| services.openfga.values.datastore.migrations.image.tag | string | `"v2.0"` |  |
| services.openfga.values.extraEnvVars[0].name | string | `"OPENFGA_EXPERIMENTALS"` |  |
| services.openfga.values.extraEnvVars[0].value | string | `"enable-list-users"` |  |
| services.openfga.values.global.imagePullSecrets[0].name | string | `"github"` |  |
| services.openfga.values.image.repository | string | `"openfga/openfga"` |  |
| services.openfga.values.image.tag | string | `""` |  |
| services.openfga.values.log.level | string | `"info"` |  |
| services.openfga.values.migrate.annotations."sidecar.istio.io/inject" | string | `"false"` |  |
| services.openfga.values.podAnnotations."traffic.sidecar.istio.io/excludeInboundPorts" | string | `"2112"` |  |
| services.openfga.values.postgresql.enabled | bool | `true` |  |
| services.openfga.values.postgresql.image.registry | string | `"ghcr.io/platform-mesh"` |  |
| services.openfga.values.postgresql.image.repository | string | `"images/postgresql"` |  |
| services.openfga.values.postgresql.nameOverride | string | `"postgres"` |  |
| services.openfga.values.replicaCount | int | `1` |  |
| services.openfga.values.telemetry.trace.enabled | bool | `false` |  |
| services.openfga.values.telemetry.trace.otlp.endpoint | string | `"observability-opentelemetry-collector.observability.svc.cluster.local:4317"` |  |
| services.openfga.values.telemetry.trace.otlp.tls.enabled | bool | `false` |  |
| services.portal.enabled | bool | `false` |  |
| services.portal.imageResources | list | `[{"annotations":{"artifact":"image","for":"portal","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.portal.values.auth.default.baseDomain | string | `"{{ .Values.baseDomain }}"` |  |
| services.portal.values.auth.default.clientId | string | `"welcome"` |  |
| services.portal.values.auth.default.clientSecretKey | string | `"attribute.client_secret"` |  |
| services.portal.values.auth.default.clientSecretName | string | `"portal-client-secret-welcome"` |  |
| services.portal.values.auth.default.discoveryUrl | string | `"https://{{ .Values.baseDomainPort }}/keycloak/realms/${org-name}/.well-known/openid-configuration"` |  |
| services.portal.values.cookieDomain | string | `"{{ .Values.baseDomain }}"` |  |
| services.portal.values.crdGatewayApiUrl | string | `"https://${org-subdomain}{{ .Values.baseDomain }}/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql"` |  |
| services.portal.values.environment | string | `"kind"` |  |
| services.portal.values.extraEnvVars[0].name | string | `"DEFAULT_PORTAL_CONTEXT_CRD_GATEWAY_API_URL"` |  |
| services.portal.values.extraEnvVars[0].value | string | `"https://${org-subdomain}{{ .Values.baseDomainPort }}/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql"` |  |
| services.portal.values.extraEnvVars[1].name | string | `"OPENMFP_PORTAL_CONTEXT_IAM_SERVICE_API_URL"` |  |
| services.portal.values.extraEnvVars[1].value | string | `"https://${org-subdomain}{{ .Values.baseDomainPort }}/iam/graphql"` |  |
| services.portal.values.frontendPort | string | `"{{ .Values.port }}"` |  |
| services.portal.values.http.protocol | string | `"https"` |  |
| services.portal.values.kcp.kubeconfigSecret | string | `"portal-kubeconfig"` |  |
| services.portal.values.virtualService.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.portal.values.virtualService.hosts[1] | string | `"*.{{ .Values.baseDomain }}"` |  |
| services.rebac-authz-webhook.enabled | bool | `true` |  |
| services.rebac-authz-webhook.imageResources | list | `[{"annotations":{"artifact":"image","for":"rebac-authz-webhook","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.rebac-authz-webhook.values.certManager.createCA | bool | `true` |  |
| services.rebac-authz-webhook.values.certManager.enabled | bool | `true` |  |
| services.rebac-authz-webhook.values.log.level | string | `"debug"` |  |
| services.rebac-authz-webhook.values.openfga.url | string | `"openfga:8081"` |  |
| services.security-operator.enabled | bool | `true` |  |
| services.security-operator.imageResources | list | `[{"annotations":{"artifact":"image","for":"security-operator","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.security-operator.values.baseDomain | string | `"{{ .Values.baseDomainPort }}"` |  |
| services.security-operator.values.crds.enabled | bool | `false` |  |
| services.security-operator.values.fga.inviteKeycloakBaseUrl | string | `"https://{{ .Values.baseDomainPort }}/keycloak"` |  |
| services.security-operator.values.fga.target | string | `"openfga.platform-mesh-system.svc.cluster.local:8081"` |  |
| services.security-operator.values.initializer.kubeconfigSecret | string | `"security-initializer-kubeconfig"` |  |
| services.security-operator.values.kubeconfigSecret | string | `"security-operator-kubeconfig"` |  |
| services.security-operator.values.log.level | string | `"debug"` |  |
| services.security-operator.values.operator.maxConcurrentReconciles | int | `1` |  |
| services.security-operator.values.operator.shutdownTimeout | string | `"1m"` |  |
| services.virtual-workspaces.enabled | bool | `true` |  |
| services.virtual-workspaces.imageResources | list | `[{"annotations":{"artifact":"image","for":"virtual-workspaces","repo":"oci"}}]` | Allow the configuration of additional ocm resources |
| services.virtual-workspaces.values.deployment.resourceSchemaName | string | `"v250704-6d57f16.contentconfigurations.ui.platform-mesh.io"` |  |
| services.virtual-workspaces.values.deployment.resourceSchemaWorkspace | string | `"root:platform-mesh-system"` |  |
| services.virtual-workspaces.values.deployment.serverUrl | string | `"https://frontproxy-front-proxy.platform-mesh-system:6443"` |  |
| services.virtual-workspaces.values.virtualWorkspaceSecretName | string | `"virtual-workspaces-cert"` |  |
| targetNamespace | string | `"platform-mesh-system"` |  |
| timeout | string | `"30m"` |  |

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
