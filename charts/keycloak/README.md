# keycloak

A Helm chart to deploy keycloak as OIDC provider in platform-mesh

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crossplane.clients.platform-mesh.name | string | `"Platform Mesh"` |  |
| crossplane.clients.platform-mesh.validRedirectUris[0] | string | `"http://localhost:8000/callback*"` |  |
| crossplane.clients.platform-mesh.validRedirectUris[1] | string | `"http://localhost:4300/callback*"` |  |
| crossplane.enabled | bool | `true` |  |
| crossplane.identityProviders | object | `{}` |  |
| crossplane.providerConfig.name | string | `"keycloak-provider-config"` |  |
| crossplane.providerConfig.namespace | string | `"platform-mesh-system"` |  |
| crossplane.realm.accessTokenLifespan | string | `"8h"` |  |
| crossplane.realm.displayName | string | `"Platform Mesh"` |  |
| crossplane.realm.name | string | `"platform-mesh"` |  |
| crossplane.realm.registrationAllowed | bool | `true` |  |
| crossplane.trustedAudiences | list | `[]` |  |
| debug | bool | `false` |  |
| domain.name | string | `"platform-mesh.org"` |  |
| domain.pathPrefix | string | `"/keycloak"` |  |
| externalSecrets.keycloakAdminRemoteRef | string | `""` |  |
| externalSecrets.postgres-adminRemoteRef | string | `""` |  |
| istio.https.port | int | `8443` |  |
| istio.virtualservice.hosts[0] | string | `"*"` |  |
| job.annotations."argocd.argoproj.io/hook" | string | `"PostSync"` |  |
| job.serviceAccount | string | `"keycloak-client-creation"` |  |
| keycloak.auth.adminUser | string | `"keycloak-admin"` |  |
| keycloak.auth.existingSecret | string | `"keycloak-admin"` |  |
| keycloak.auth.passwordSecretKey | string | `"secret"` |  |
| keycloak.extraEnvVars[0].name | string | `"KEYCLOAK_USER"` |  |
| keycloak.extraEnvVars[0].value | string | `"keycloak-admin"` |  |
| keycloak.extraEnvVars[1].name | string | `"KEYCLOAK_PASSWORD"` |  |
| keycloak.extraEnvVars[1].valueFrom.secretKeyRef.key | string | `"secret"` |  |
| keycloak.extraEnvVars[1].valueFrom.secretKeyRef.name | string | `"keycloak-admin"` |  |
| keycloak.extraEnvVars[2].name | string | `"JAVA_OPTS_APPEND"` |  |
| keycloak.extraEnvVars[2].value | string | `"-Djgroups.dns.query=platform-mesh-keycloak-headless.platform-mesh-system.svc.cluster.local"` |  |
| keycloak.httpRelativePath | string | `"/keycloak/"` |  |
| keycloak.postgresql.auth.existingSecret | string | `""` |  |
| keycloak.postgresql.auth.secretKeys.adminPasswordKey | string | `"password"` |  |
| keycloak.postgresql.auth.secretKeys.userPasswordKey | string | `"password"` |  |
| keycloak.postgresql.auth.username | string | `"keycloak"` |  |
| keycloak.postgresql.nameOverride | string | `"postgresql-keycloak"` |  |
| keycloak.postgresql.primary.resourcesPreset | string | `"none"` |  |
| keycloakConfig.admin.password.valueFrom.secretKeyRef.key | string | `"secret"` |  |
| keycloakConfig.admin.password.valueFrom.secretKeyRef.name | string | `"keycloak-admin"` |  |
| keycloakConfig.admin.username.value | string | `"keycloak-admin"` |  |
| keycloakConfig.client.name | string | `"platform-mesh"` |  |
| keycloakConfig.client.targetSecret.name | string | `"portal-client-secret-platform-mesh"` |  |
| keycloakConfig.client.targetSecret.namespace | string | `"platform-mesh-system"` |  |
| keycloakConfig.client.tokenLifespan | int | `3600` |  |
| keycloakConfig.realm.name | string | `"master"` |  |
| keycloakConfig.redirectUrls[0] | string | `"http://localhost:8000/callback*"` |  |
| keycloakConfig.url | string | `"http://platform-mesh-keycloak.platform-mesh-system.svc.cluster.local/keycloak"` |  |
| keycloakConfig.userRegistration.enabled | bool | `true` |  |
| service.name | string | `"platform-mesh-keycloak"` |  |
| service.port | int | `80` |  |

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
# keycloak

![Version: 0.64.13](https://img.shields.io/badge/Version-0.64.13-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

A Helm chart to deploy keycloak as OIDC provider in platform-mesh

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/platform-mesh/helm-charts | common | 0.5.5 |
| oci://registry-1.docker.io/bitnamicharts | keycloak(keycloak) | 25.0.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crossplane.clients.platform-mesh.name | string | `"Platform Mesh"` |  |
| crossplane.clients.platform-mesh.validRedirectUris[0] | string | `"http://localhost:8000/callback*"` |  |
| crossplane.clients.platform-mesh.validRedirectUris[1] | string | `"http://localhost:4300/callback*"` |  |
| crossplane.enabled | bool | `true` |  |
| crossplane.identityProviders | object | `{}` |  |
| crossplane.providerConfig.name | string | `"keycloak-provider-config"` |  |
| crossplane.providerConfig.namespace | string | `"platform-mesh-system"` |  |
| crossplane.realm.accessTokenLifespan | string | `"8h"` |  |
| crossplane.realm.displayName | string | `"Platform Mesh"` |  |
| crossplane.realm.name | string | `"platform-mesh"` |  |
| crossplane.realm.registrationAllowed | bool | `true` |  |
| crossplane.trustedAudiences | list | `[]` |  |
| debug | bool | `false` |  |
| domain.name | string | `"platform-mesh.org"` |  |
| domain.pathPrefix | string | `"/keycloak"` |  |
| externalSecrets.keycloakAdminRemoteRef | string | `""` |  |
| externalSecrets.postgres-adminRemoteRef | string | `""` |  |
| istio.https.port | int | `8443` |  |
| istio.virtualservice.hosts[0] | string | `"*"` |  |
| job.annotations."argocd.argoproj.io/hook" | string | `"PostSync"` |  |
| job.serviceAccount | string | `"keycloak-client-creation"` |  |
| keycloak.auth.adminUser | string | `"keycloak-admin"` |  |
| keycloak.auth.existingSecret | string | `"keycloak-admin"` |  |
| keycloak.auth.passwordSecretKey | string | `"secret"` |  |
| keycloak.extraEnvVars[0].name | string | `"KEYCLOAK_USER"` |  |
| keycloak.extraEnvVars[0].value | string | `"keycloak-admin"` |  |
| keycloak.extraEnvVars[1].name | string | `"KEYCLOAK_PASSWORD"` |  |
| keycloak.extraEnvVars[1].valueFrom.secretKeyRef.key | string | `"secret"` |  |
| keycloak.extraEnvVars[1].valueFrom.secretKeyRef.name | string | `"keycloak-admin"` |  |
| keycloak.extraEnvVars[2].name | string | `"JAVA_OPTS_APPEND"` |  |
| keycloak.extraEnvVars[2].value | string | `"-Djgroups.dns.query=platform-mesh-keycloak-headless.platform-mesh-system.svc.cluster.local"` |  |
| keycloak.httpRelativePath | string | `"/keycloak/"` |  |
| keycloak.postgresql.auth.existingSecret | string | `""` |  |
| keycloak.postgresql.auth.secretKeys.adminPasswordKey | string | `"password"` |  |
| keycloak.postgresql.auth.secretKeys.userPasswordKey | string | `"password"` |  |
| keycloak.postgresql.auth.username | string | `"keycloak"` |  |
| keycloak.postgresql.nameOverride | string | `"postgresql-keycloak"` |  |
| keycloak.postgresql.primary.resourcesPreset | string | `"none"` |  |
| keycloakConfig.admin.password.valueFrom.secretKeyRef.key | string | `"secret"` |  |
| keycloakConfig.admin.password.valueFrom.secretKeyRef.name | string | `"keycloak-admin"` |  |
| keycloakConfig.admin.username.value | string | `"keycloak-admin"` |  |
| keycloakConfig.client.name | string | `"platform-mesh"` |  |
| keycloakConfig.client.targetSecret.name | string | `"portal-client-secret-platform-mesh"` |  |
| keycloakConfig.client.targetSecret.namespace | string | `"platform-mesh-system"` |  |
| keycloakConfig.client.tokenLifespan | int | `3600` |  |
| keycloakConfig.realm.name | string | `"master"` |  |
| keycloakConfig.redirectUrls[0] | string | `"http://localhost:8000/callback*"` |  |
| keycloakConfig.url | string | `"http://platform-mesh-keycloak.platform-mesh-system.svc.cluster.local/keycloak"` |  |
| keycloakConfig.userRegistration.enabled | bool | `true` |  |
| service.name | string | `"platform-mesh-keycloak"` |  |
| service.port | int | `80` |  |

