# platform-mesh-operator-components

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hostAliases | list | `[]` |  |
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
| services.account-operator.values | string | `"tracing:\n  enabled: false\n  collector:\n    host: observability-opentelemetry-collector.observability.svc.cluster.local:4317\nkubeconfigSecret: account-operator-kubeconfig\nlog:\n  level: debug\ncrds:\n  enabled: false\nkcp:\n  enabled: true\n  apiExportEndpointSliceName: \"\"\nsubroutines:\n  fga:\n    grpcAddr: openfga:8081\n"` |  |
| services.crossplane.enabled | bool | `true` |  |
| services.crossplane.helmRepo | bool | `true` |  |
| services.crossplane.targetNamespace | string | `"crossplane-system"` |  |
| services.crossplane.values | string | `"provider:\n  packages:\n    - xpkg.upbound.io/crossplane-contrib/provider-keycloak:v2.7.2\n"` |  |
| services.etcd-druid.enabled | bool | `true` |  |
| services.etcd-druid.gitRepo | bool | `true` |  |
| services.etcd-druid.imageResource.enabled | bool | `true` |  |
| services.etcd-druid.path | string | `"charts"` |  |
| services.etcd-druid.targetNamespace | string | `"etcd-druid-system"` |  |
| services.etcd-druid.values | string | `""` |  |
| services.extension-manager-operator.enabled | bool | `true` |  |
| services.extension-manager-operator.values | string | `"crds:\n  enabled: false\nkcp:\n  enabled: true\n  kubeconfigSecret: extension-manager-operator-kubeconfig\ntracing:\n  enabled: false\n  collector:\n    host: observability-opentelemetry-collector.observability.svc.cluster.local:4317\n"` |  |
| services.iam-service.enabled | bool | `false` |  |
| services.iam-service.values | string | `"istio:\n  hosts:\n    - \"*.{{ .Values.baseDomain }}\"\n"` |  |
| services.infra.dependsOn[0].name | string | `"kcp-operator"` |  |
| services.infra.dependsOn[0].namespace | string | `"default"` |  |
| services.infra.enabled | bool | `true` |  |
| services.infra.values | string | `"hostAliases: {{- .Values.hostAliases | toYaml | nindent 2 }}\nkcp:\n  image:\n    # FIXME: this is a temporary fix until we have support for the latest version\n    tag: 8265c399b\n  rootShard:\n    extraArgs:\n      - --feature-gates=WorkspaceAuthentication=true\n      - --shard-virtual-workspace-url=https://kcp.api.{{ .Values.baseDomainPort }}\n  webhook:\n    enabled: true\nistio:\n  main:\n    gateway:\n      hosts:\n        - \"{{ .Values.baseDomain }}\"\n        - \"*.{{ .Values.baseDomain }}\"\n      port: '{{ .Values.port }}'\n      name: https\n      protocol: HTTPS\n      tls:\n        mode: SIMPLE\n        credentialName: domain-certificate\n        minProtocolVersion: TLSV1_2\n  passThrough:\n    gateway:\n      enabled: true\n      hosts:\n        - \"kcp.api.{{ .Values.baseDomain }}\"\n      port: '{{ .Values.port }}'\n      name: pass-https\n      protocol: HTTPS\nkeycloak:\n  istio:\n    virtualservice:\n      hosts:\n        - \"{{ .Values.baseDomain }}\"\n  crossplane:\n    clients:\n      welcome:\n        validRedirectUris:\n          - \"https://{{ .Values.baseDomainPort }}/callback*\"\n"` |  |
| services.kcp-operator.enabled | bool | `true` |  |
| services.kcp-operator.helmRepo | bool | `true` |  |
| services.kcp-operator.imageResource.enabled | bool | `true` |  |
| services.kcp-operator.imageResource.labels.component | string | `"infra"` |  |
| services.kcp-operator.imageResource.labels.infra | string | `"true"` |  |
| services.kcp-operator.imageResource.name | string | `"kcp-image"` |  |
| services.kcp-operator.targetNamespace | string | `"kcp-operator"` |  |
| services.kcp-operator.values | string | `"image:\n  tag: \"v0.3.0\"\n"` |  |
| services.keycloak.enabled | bool | `true` |  |
| services.keycloak.values | string | `"global:\n  imagePullSecrets:\n    - name: github\n  security:\n    allowInsecureImages: true\nresources:\n  limits:\n    cpu: \"2\"\n    ephemeral-storage: 2Gi\n    memory: 2Gi\n  requests:\n    cpu: 750m\n    ephemeral-storage: 50Mi\n    memory: 1Gi\nimage:\n  registry: ghcr.io/platform-mesh\n  repository: upstream-images/keycloak\nauth:\n  # -- keycloak admin user\n  adminUser: keycloak-admin\n  # -- keycloak admin secret\n  existingSecret: keycloak-admin\n  # -- keycloak admin secret key\n  passwordSecretKey: secret\n# -- keycloak http relative path\nhttpRelativePath: \"/keycloak/\"\n# -- keycloak environment variables (raw)\n# For Arm64 arch (especially Apple M4), add -XX:UseSVE=0 to JAVA_OPTS_APPEND\nextraEnvVars:\n  - name: JAVA_OPTS_APPEND\n    value: |-\n      -Djgroups.dns.query=keycloak-headless.platform-mesh-system.svc.cluster.local\n  - name: KC_PROXY_HEADERS\n    value: xforwarded\n  - name: KC_HOSTNAME_STRICT\n    value: \"false\"\n# -- configuration for the postgresql sub-chart\npostgresql:\n  image:\n    registry: ghcr.io/platform-mesh\n    repository: upstream-images/postgresql\n    tag: 17.6.0-debian-12-r4\n  primary:\n    # -- primary postgresql resources preset\n    resourcesPreset: none\n  # -- postgresql name override\n  nameOverride: postgresql-keycloak\n  # -- authorization configuration\n  auth:\n    # -- postgresql username\n    username: keycloak\n    # -- existing secret name\n    existingSecret: \"\"\n    secretKeys:\n      # -- user password key\n      userPasswordKey: password\n      # -- admin password key\n      adminPasswordKey: password\n"` |  |
| services.kubernetes-graphql-gateway.enabled | bool | `true` |  |
| services.kubernetes-graphql-gateway.values | string | `"tracing:\n  enabled: false\ntrust:\n  default:\n    trustedIssuer: \"https://{{ .Values.baseDomainPort }}/keycloak/realms/default\"\n    jwksUrl: http://keycloak-headless.platform-mesh-system:8080/keycloak/realms/default/protocol/openid-connect/certs\n    audience: default\nkubeConfig:\n  enabled: true\n  secretName: kubernetes-grapqhl-gateway-kubeconfig\nvirtualService:\n  pathPrefix: /api/kubernetes-graphql-gateway/\n  hosts:\n    - \"{{ .Values.baseDomain }}\"\n    - \"*.{{ .Values.baseDomain }}\"\n  httpRules:\n    - name: default\n      cors:\n        allowHeaders:\n          - \"*\"\n        allowMethods:\n          - GET\n          - POST\n        allowOrigins:\n          - regex: .*\nlistener:\n  virtualWorkspacesConfig:\n    enabled: true\n    content:\n      virtualWorkspaces:\n        - name: contentconfigurations\n          url: \"https://kcp-front-proxy.platform-mesh-system:8443/services/contentconfigurations\"\n          kubeconfig: /app/kubeconfig/kubeconfig\n        - name: marketplace\n          url: \"https://kcp-front-proxy.platform-mesh-system:8443/services/marketplace\"\n          kubeconfig: /app/kubeconfig/kubeconfig\n"` |  |
| services.observability.enabled | bool | `false` |  |
| services.observability.targetNamespace | string | `"observability"` |  |
| services.observability.values | string | `"istio:\n  grafana:\n    virtualService:\n      hosts: [\"grafana.{{ .Values.baseDomain }}\"]\n  tracing:\n    enabled: false\nopentelemetry-collector:\n  service:\n    type: ClusterIP\n  ports:\n    metrics:\n      enabled: true\n"` |  |
| services.openfga.enabled | bool | `true` |  |
| services.openfga.helmRepo | bool | `true` |  |
| services.openfga.values | string | `"global:\n  imagePullSecrets:\n    - name: github\nmigrate:\n  annotations:\n    sidecar.istio.io/inject: \"false\"\nextraEnvVars:\n  - name: OPENFGA_EXPERIMENTALS\n    value: enable-list-users\nlog:\n  level: info\nautoscaling:\n  enabled: false\nimage:\n  repository: \"openfga/openfga\"\n  tag: \"\"\nreplicaCount: 1\npodAnnotations:\n  traffic.sidecar.istio.io/excludeInboundPorts: \"2112\"\ncheckQueryCache:\n  enabled: true\n  limit: 10000\n  ttl: 10s\ndatastore:\n  engine: postgres\n  maxOpenConns: 30\n  applyMigrations: true\n  migrationType: \"initContainer\"\n  migrations:\n    image:\n      repository: groundnuty/k8s-wait-for\n      pullPolicy: Always\n      tag: \"v2.0\"\npostgresql:\n  ## @param postgresql.enabled enable the bitnami/postgresql subchart and deploy Postgres\n  enabled: true\n  nameOverride: postgres\n  image:\n    registry: ghcr.io/platform-mesh\n    repository: images/postgresql\ntelemetry:\n  trace:\n    enabled: true\n    otlp:\n      endpoint: observability-opentelemetry-collector.openmfp-observability.svc.cluster.local:4317\n      tls:\n        enabled: false\n"` |  |
| services.organization-idp.dependsOn[0].name | string | `"keycloak"` |  |
| services.organization-idp.dependsOn[0].namespace | string | `"default"` |  |
| services.organization-idp.enabled | bool | `true` |  |
| services.organization-idp.skipHelmRelease | bool | `true` |  |
| services.organization-idp.values | string | `""` |  |
| services.portal.enabled | bool | `false` |  |
| services.portal.values | string | `"deployment:\n  hostAliases: {{- .Values.hostAliases | toYaml | nindent 2 }}\nkcp:\n  kubeconfigSecret: portal-kubeconfig\ncrdGatewayApiUrl: \"https://${org-subdomain}{{ .Values.baseDomain }}/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql\"\nenvironment: kind\nhttp:\n  protocol: https\nfrontendPort: '{{ .Values.port }}'\nauth:\n  default:\n    discoveryUrl: \"https://{{ .Values.baseDomainPort }}/keycloak/realms/${org-name}/.well-known/openid-configuration\"\n    clientSecretName: \"portal-client-secret-welcome\"\n    clientSecretKey: \"attribute.client_secret\"\n    clientId: \"welcome\"\n    baseDomain: \"{{ .Values.baseDomain }}\"\nvirtualService:\n  hosts:\n    - \"{{ .Values.baseDomain }}\"\n    - \"*.{{ .Values.baseDomain }}\"\ncookieDomain: \"{{ .Values.baseDomain }}\"\nextraEnvVars:\n  - name: DEFAULT_PORTAL_CONTEXT_CRD_GATEWAY_API_URL\n    value: https://${org-subdomain}{{ .Values.baseDomainPort }}/api/kubernetes-graphql-gateway/root:orgs:${org-name}/graphql\n  - name: OPENMFP_PORTAL_CONTEXT_IAM_SERVICE_API_URL\n    value: \"https://${org-subdomain}{{ .Values.baseDomainPort }}/iam/graphql\"\n"` |  |
| services.rebac-authz-webhook.enabled | bool | `true` |  |
| services.rebac-authz-webhook.values | string | `"log:\n  level: debug\nopenfga:\n  url: openfga:8081\nistio:\n  exposed: false\n  dnsNames:\n    - rebac-authz-webhook.platform-mesh-system.svc.cluster.local\ncertManager:\n  enabled: true\n  createCA: true\n"` |  |
| services.security-operator.enabled | bool | `true` |  |
| services.security-operator.values | string | `"hostAliases: {{- .Values.hostAliases | toYaml | nindent 2 }}\ncrds:\n  enabled: false\nfga:\n  target: openfga.platform-mesh-system.svc.cluster.local:8081\n  inviteKeycloakBaseUrl: \"https://{{ .Values.baseDomainPort }}/keycloak\"\ninitializer:\n  kubeconfigSecret: security-initializer-kubeconfig\nbaseDomain: \"{{ .Values.baseDomainPort }}\"\nkubeconfigSecret: security-operator-kubeconfig\nlog:\n  level: debug\noperator:\n  shutdownTimeout: 1m\n  maxConcurrentReconciles: 1\n"` |  |
| services.virtual-workspaces.enabled | bool | `true` |  |
| services.virtual-workspaces.values | string | `""` |  |
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
