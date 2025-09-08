# platform-mesh-operator-components

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| baseDomain | string | `"example.com"` |  |
| componentVersion.semver | string | `"0.0.81"` |  |
| iamWebhookCA | string | `nil` |  |
| ociPullSecret | string | `"ocm-oci-github-pull"` |  |
| ocm.component.create | bool | `true` |  |
| ocm.component.name | string | `"platform-mesh"` |  |
| ocm.interval | string | `"3m"` |  |
| ocm.referencePath | list | `[]` |  |
| ocm.repo.create | bool | `true` |  |
| ocm.repo.name | string | `"platform-mesh"` |  |
| port | int | `443` |  |
| protocol | string | `"https"` |  |
| services.account-operator.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.account-operator.dependsOn[0].namespace | string | `"default"` |  |
| services.account-operator.enabled | bool | `true` |  |
| services.account-operator.values.crds.enabled | bool | `false` |  |
| services.account-operator.values.kcp.apiExportEndpointSliceName | string | `""` |  |
| services.account-operator.values.kcp.enabled | bool | `true` |  |
| services.account-operator.values.kubeconfigSecret | string | `"account-operator-kubeconfig"` |  |
| services.account-operator.values.log.level | string | `"debug"` |  |
| services.account-operator.values.subroutines.fga.grpcAddr | string | `"openfga:8081"` |  |
| services.account-operator.values.tracing.collector.host | string | `"observability-opentelemetry-collector.observability.svc.cluster.local:4317"` |  |
| services.account-operator.values.tracing.enabled | bool | `true` |  |
| services.crossplane.enabled | bool | `true` |  |
| services.crossplane.helmRepo | bool | `true` |  |
| services.crossplane.targetNamespace | string | `"crossplane-system"` |  |
| services.crossplane.values.provider.packages[0] | string | `"xpkg.upbound.io/crossplane-contrib/provider-keycloak:v1.9.2"` |  |
| services.etcd-druid.enabled | bool | `true` |  |
| services.etcd-druid.gitRepo | bool | `true` |  |
| services.etcd-druid.path | string | `"charts"` |  |
| services.etcd-druid.targetNamespace | string | `"etcd-druid-system"` |  |
| services.etcd-druid.values | object | `{}` |  |
| services.extension-manager-operator.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.extension-manager-operator.dependsOn[0].namespace | string | `"default"` |  |
| services.extension-manager-operator.enabled | bool | `true` |  |
| services.extension-manager-operator.values.crds.enabled | bool | `false` |  |
| services.extension-manager-operator.values.kcp.enabled | bool | `true` |  |
| services.extension-manager-operator.values.kcp.kubeconfigSecret | string | `"extension-manager-operator-kubeconfig"` |  |
| services.extension-manager-operator.values.tracing.collector.host | string | `"observability-opentelemetry-collector.observability.svc.cluster.local:4317"` |  |
| services.extension-manager-operator.values.tracing.enabled | bool | `true` |  |
| services.iam-service.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.iam-service.dependsOn[0].namespace | string | `"default"` |  |
| services.iam-service.dependsOn[1].name | string | `"openfga"` |  |
| services.iam-service.dependsOn[1].namespace | string | `"default"` |  |
| services.iam-service.enabled | bool | `true` |  |
| services.iam-service.values.gateway.name | string | `"gateway"` |  |
| services.iam-service.values.hostname | string | `"api.{{ .Values.baseDomain }}"` |  |
| services.iam-service.values.trust.default.audience | string | `"default"` |  |
| services.iam-service.values.trust.default.jwksUrl | string | `"http://keycloak-headless.platform-mesh-system:8080/keycloak/realms/default/protocol/openid-connect/certs"` |  |
| services.iam-service.values.trust.default.trustedIssuer | string | `"https://{{ .Values.baseDomain }}:{{ .Values.port }}/keycloak/realms/default"` |  |
| services.iam-ui.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.iam-ui.dependsOn[0].namespace | string | `"default"` |  |
| services.iam-ui.enabled | bool | `true` |  |
| services.iam-ui.values.istio.virtualService.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.infra.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.infra.dependsOn[0].namespace | string | `"default"` |  |
| services.infra.dependsOn[1].name | string | `"kcp-operator"` |  |
| services.infra.dependsOn[1].namespace | string | `"default"` |  |
| services.infra.enabled | bool | `true` |  |
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
| services.infra.values.keycloak.istio.virtualservice.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.istio-base.chart | string | `"base"` |  |
| services.istio-base.driftDetectionMode | string | `"disabled"` |  |
| services.istio-base.enabled | bool | `true` |  |
| services.istio-base.helmRepo | bool | `true` |  |
| services.istio-base.install.createNamespace | bool | `true` |  |
| services.istio-base.targetNamespace | string | `"istio-system"` |  |
| services.istio-gateway.chart | string | `"gateway"` |  |
| services.istio-gateway.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.istio-gateway.dependsOn[0].namespace | string | `"default"` |  |
| services.istio-gateway.enabled | bool | `true` |  |
| services.istio-gateway.helmRepo | bool | `true` |  |
| services.istio-gateway.targetNamespace | string | `"istio-system"` |  |
| services.istio-gateway.values.service.ports[0].name | string | `"https"` |  |
| services.istio-gateway.values.service.ports[0].nodePort | int | `31000` |  |
| services.istio-gateway.values.service.ports[0].port | int | `8443` |  |
| services.istio-gateway.values.service.ports[1].name | string | `"status-port"` |  |
| services.istio-gateway.values.service.ports[1].nodePort | int | `32000` |  |
| services.istio-gateway.values.service.ports[1].port | int | `15021` |  |
| services.istio-gateway.values.service.type | string | `"NodePort"` |  |
| services.istio-istiod.chart | string | `"istiod"` |  |
| services.istio-istiod.dependsOn[0].name | string | `"istio-base"` |  |
| services.istio-istiod.dependsOn[0].namespace | string | `"default"` |  |
| services.istio-istiod.driftDetectionMode | string | `"disabled"` |  |
| services.istio-istiod.enabled | bool | `true` |  |
| services.istio-istiod.helmRepo | bool | `true` |  |
| services.istio-istiod.targetNamespace | string | `"istio-system"` |  |
| services.istio-istiod.values.meshConfig.defaultConfig.holdApplicationUntilProxyStarts | bool | `true` |  |
| services.istio-istiod.values.meshConfig.defaultConfig.tracing.provider.name | string | `"otel-tracing"` |  |
| services.istio-istiod.values.meshConfig.extensionProviders[0].name | string | `"otel-tracing"` |  |
| services.istio-istiod.values.meshConfig.extensionProviders[0].opentelemetry.port | int | `4317` |  |
| services.istio-istiod.values.meshConfig.extensionProviders[0].opentelemetry.protocol | string | `"grpc"` |  |
| services.istio-istiod.values.meshConfig.extensionProviders[0].opentelemetry.service | string | `"observability-opentelemetry-collector.observability.svc.cluster.local"` |  |
| services.istio-istiod.values.tracing.enabled | bool | `false` |  |
| services.istio-istiod.values.tracing.telemetry.tracing[0].providers[0].name | string | `"otel-tracing"` |  |
| services.istio-istiod.values.tracing.telemetry.tracing[0].randomSamplingPercentage | int | `100` |  |
| services.kcp-operator.enabled | bool | `true` |  |
| services.kcp-operator.helmRepo | bool | `true` |  |
| services.kcp-operator.targetNamespace | string | `"kcp-operator"` |  |
| services.keycloak.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.keycloak.dependsOn[0].namespace | string | `"default"` |  |
| services.keycloak.enabled | bool | `true` |  |
| services.keycloak.values.auth.adminUser | string | `"keycloak-admin"` | keycloak admin user |
| services.keycloak.values.auth.existingSecret | string | `"keycloak-admin"` | keycloak admin secret |
| services.keycloak.values.auth.passwordSecretKey | string | `"secret"` | keycloak admin secret key |
| services.keycloak.values.extraEnvVars | list | `[{"name":"JAVA_OPTS_APPEND","value":"-Djgroups.dns.query=keycloak-headless.platform-mesh-system.svc.cluster.local"},{"name":"KC_PROXY_HEADERS","value":"xforwarded"},{"name":"KC_HOSTNAME_STRICT","value":"false"}]` | keycloak environment variables (raw) For Arm64 arch (especially Apple M4), add -XX:UseSVE=0 to JAVA_OPTS_APPEND |
| services.keycloak.values.httpRelativePath | string | `"/keycloak/"` | keycloak http relative path |
| services.keycloak.values.postgresql | object | `{"auth":{"existingSecret":"","secretKeys":{"adminPasswordKey":"password","userPasswordKey":"password"},"username":"keycloak"},"nameOverride":"postgresql-keycloak","primary":{"resourcesPreset":"none"}}` | configuration for the postgresql sub-chart |
| services.keycloak.values.postgresql.auth | object | `{"existingSecret":"","secretKeys":{"adminPasswordKey":"password","userPasswordKey":"password"},"username":"keycloak"}` | authorization configuration |
| services.keycloak.values.postgresql.auth.existingSecret | string | `""` | existing secret name |
| services.keycloak.values.postgresql.auth.secretKeys.adminPasswordKey | string | `"password"` | admin password key |
| services.keycloak.values.postgresql.auth.secretKeys.userPasswordKey | string | `"password"` | user password key |
| services.keycloak.values.postgresql.auth.username | string | `"keycloak"` | postgresql username |
| services.keycloak.values.postgresql.nameOverride | string | `"postgresql-keycloak"` | postgresql name override |
| services.keycloak.values.postgresql.primary.resourcesPreset | string | `"none"` | primary postgresql resources preset |
| services.kubernetes-graphql-gateway.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.kubernetes-graphql-gateway.dependsOn[0].namespace | string | `"default"` |  |
| services.kubernetes-graphql-gateway.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.kubeConfig.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.kubeConfig.secretName | string | `"kubernetes-grapqhl-gateway-kubeconfig"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[0].kubeconfig | string | `"/app/kubeconfig/kubeconfig"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[0].name | string | `"contentconfigurations"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[0].url | string | `"https://kcp-front-proxy.platform-mesh-system:8443/services/contentconfigurations"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[1].kubeconfig | string | `"/app/kubeconfig/kubeconfig"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[1].name | string | `"marketplace"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.content.virtualWorkspaces[1].url | string | `"https://kcp-front-proxy.platform-mesh-system:8443/services/marketplace"` |  |
| services.kubernetes-graphql-gateway.values.listener.virtualWorkspacesConfig.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values.trust.default.audience | string | `"default"` |  |
| services.kubernetes-graphql-gateway.values.trust.default.jwksUrl | string | `"http://keycloak-headless.platform-mesh-system:8080/keycloak/realms/default/protocol/openid-connect/certs"` |  |
| services.kubernetes-graphql-gateway.values.trust.default.trustedIssuer | string | `"https://{{ .Values.baseDomain }}:{{ .Values.port }}/keycloak/realms/default"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.hosts[1] | string | `"*.{{ .Values.baseDomain }}"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowHeaders[0] | string | `"*"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowMethods[0] | string | `"GET"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowMethods[1] | string | `"POST"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].cors.allowOrigins[0].regex | string | `".*"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.httpRules[0].name | string | `"default"` |  |
| services.kubernetes-graphql-gateway.values.virtualService.pathPrefix | string | `"/api/kubernetes-graphql-gateway/"` |  |
| services.marketplace-ui.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.marketplace-ui.dependsOn[0].namespace | string | `"default"` |  |
| services.marketplace-ui.enabled | bool | `false` |  |
| services.marketplace-ui.values.istio.virtualService.hosts[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.observability.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.observability.dependsOn[0].namespace | string | `"default"` |  |
| services.observability.enabled | bool | `false` |  |
| services.observability.targetNamespace | string | `"observability"` |  |
| services.observability.values.istio.grafana.virtualService.hosts[0] | string | `"grafana.{{ .Values.baseDomain }}"` |  |
| services.observability.values.istio.tracing.enabled | bool | `true` |  |
| services.observability.values.opentelemetry-collector.ports.metrics.enabled | bool | `true` |  |
| services.observability.values.opentelemetry-collector.service.type | string | `"ClusterIP"` |  |
| services.openfga.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.openfga.dependsOn[0].namespace | string | `"default"` |  |
| services.openfga.enabled | bool | `true` |  |
| services.openfga.helmRepo | bool | `true` |  |
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
| services.openfga.values.image.repository | string | `"openfga/openfga"` |  |
| services.openfga.values.image.tag | string | `""` |  |
| services.openfga.values.log.level | string | `"info"` |  |
| services.openfga.values.migrate.annotations."sidecar.istio.io/inject" | string | `"false"` |  |
| services.openfga.values.podAnnotations."traffic.sidecar.istio.io/excludeInboundPorts" | string | `"2112"` |  |
| services.openfga.values.postgresql.enabled | bool | `true` |  |
| services.openfga.values.postgresql.nameOverride | string | `"postgres"` |  |
| services.openfga.values.replicaCount | int | `1` |  |
| services.openfga.values.telemetry.trace.enabled | bool | `true` |  |
| services.openfga.values.telemetry.trace.otlp.endpoint | string | `"observability-opentelemetry-collector.openmfp-observability.svc.cluster.local:4317"` |  |
| services.openfga.values.telemetry.trace.otlp.tls.enabled | bool | `false` |  |
| services.portal.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.portal.dependsOn[0].namespace | string | `"default"` |  |
| services.portal.enabled | bool | `false` |  |
| services.portal.values.baseDomains[0] | string | `"{{ .Values.baseDomain }}"` |  |
| services.portal.values.cookieDomain | string | `"{{ .Values.baseDomain }}"` |  |
| services.portal.values.crdGatewayApiUrl | string | `"https://${org-subdomain}{{ .Values.baseDomain }}/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql"` |  |
| services.portal.values.environment | string | `"kind"` |  |
| services.portal.values.extraEnvVars[0].name | string | `"DEFAULT_PORTAL_CONTEXT_CRD_GATEWAY_API_URL"` |  |
| services.portal.values.extraEnvVars[0].value | string | `"https://${org-subdomain}{{ .Values.baseDomain }}:{{ .Values.port }}/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql"` |  |
| services.portal.values.extraEnvVars[1].name | string | `"DEFAULT_PORTAL_CONTEXT_IAM_SERVICE_API_URL"` |  |
| services.portal.values.extraEnvVars[1].value | string | `"https://{{ .Values.baseDomain }}:{{ .Values.port }}/iam/query"` |  |
| services.portal.values.extraEnvVars[2].name | string | `"DEFAULT_PORTAL_CONTEXT_IAM_ENTITY_CONFIG"` |  |
| services.portal.values.extraEnvVars[2].value | string | `"{\"account\":{\"contextProperty\":\"entityId\"}}"` |  |
| services.portal.values.frontendPort | string | `"{{ .Values.port }}"` |  |
| services.portal.values.http.protocol | string | `"https"` |  |
| services.portal.values.kubeconfigSecret | string | `"portal-kubeconfig"` |  |
| services.portal.values.trust.default.authDomain | string | `"https://{{ .Values.baseDomain }}:{{ .Values.port }}/keycloak/realms/default/protocol/openid-connect/auth"` | auth domain (if discoveryEndpoint is not specified) |
| services.portal.values.trust.default.baseDomains | string | `"portal.dev.local"` | base domains |
| services.portal.values.trust.default.contentConfigurationValidatorApiUrl | string | `"http://extension-manager-operator-server.platform-mesh-system.svc.cluster.local:8088/validate"` | ContentConfiguration validator api url |
| services.portal.values.trust.default.discoveryEndpoint | string | `""` | discovery endpoint. If specified (different than ""), authDomain and tokenUrl are not required |
| services.portal.values.trust.default.loginAudience | string | `"default"` | login audience |
| services.portal.values.trust.default.oidcClientSecretName | string | `"default-client"` | oidc client secret name |
| services.portal.values.trust.default.secretKeyRef | string | `"attribute.client_secret"` | secret key reference |
| services.portal.values.trust.default.tokenUrl | string | `"http://keycloak/keycloak/realms/default/protocol/openid-connect/token"` | token url (if discoveryEndpoint is not specified) |
| services.portal.values.virtualService.hosts | bool | `false` |  |
| services.rebac-authz-webhook.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.rebac-authz-webhook.dependsOn[0].namespace | string | `"default"` |  |
| services.rebac-authz-webhook.enabled | bool | `true` |  |
| services.rebac-authz-webhook.values.certManager.createCA | bool | `true` |  |
| services.rebac-authz-webhook.values.certManager.enabled | bool | `true` |  |
| services.rebac-authz-webhook.values.istio.dnsNames[0] | string | `"rebac-authz-webhook.platform-mesh-system.svc.cluster.local"` |  |
| services.rebac-authz-webhook.values.istio.exposed | bool | `false` |  |
| services.rebac-authz-webhook.values.log.level | string | `"debug"` |  |
| services.rebac-authz-webhook.values.openfga.url | string | `"openfga:8081"` |  |
| services.security-operator.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.security-operator.dependsOn[0].namespace | string | `"default"` |  |
| services.security-operator.enabled | bool | `true` |  |
| services.security-operator.values.crds.enabled | bool | `false` |  |
| services.security-operator.values.fga.target | string | `"openfga.platform-mesh-system.svc.cluster.local:8081"` |  |
| services.security-operator.values.initializer.kubeconfigSecret | string | `"security-initializer-kubeconfig"` |  |
| services.security-operator.values.kubeconfigSecret | string | `"security-operator-kubeconfig"` |  |
| services.security-operator.values.log.level | string | `"debug"` |  |
| services.security-operator.values.operator.maxConcurrentReconciles | int | `1` |  |
| services.security-operator.values.operator.shutdownTimeout | string | `"1m"` |  |
| services.virtual-workspaces.dependsOn[0].name | string | `"istio-istiod"` |  |
| services.virtual-workspaces.dependsOn[0].namespace | string | `"default"` |  |
| services.virtual-workspaces.enabled | bool | `true` |  |
| targetNamespace | string | `"platform-mesh-system"` |  |

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
