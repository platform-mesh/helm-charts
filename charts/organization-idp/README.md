# organization-idp

A Helm chart to deploy organization identity provider in openmfp

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crossplane.client.displayName | string | `"ClientName"` | valid redirect uris for the client |
| crossplane.client.name | string | `"clientname"` | name of the client |
| crossplane.client.validRedirectUris[0] | string | `"http://localhost:8000/callback*"` | keycloak callback url |
| crossplane.client.validRedirectUris[1] | string | `"http://localhost:4300/callback*"` |  |
| crossplane.enabled | bool | `true` | toggle to enable/disable crossplane |
| crossplane.providerConfig.name | string | `"keycloak-provider-config"` | name of the client |
| crossplane.providerConfig.namespace | string | `"platform-mesh-system"` | client namespace |
| crossplane.realm | object | `{"accessTokenLifespan":"8h","displayName":"default","name":"default","registrationAllowed":true}` | crossplane realm config |
| crossplane.realm.accessTokenLifespan | string | `"8h"` | realm access token lifespan |
| crossplane.realm.displayName | string | `"default"` | realm display name |
| crossplane.realm.name | string | `"default"` | realm name |
| crossplane.realm.registrationAllowed | bool | `true` | realm registration allowed |
| crossplane.trustedAudiences | list | `[]` |  |
| keycloakConfig.client | object | `{"name":"organizationIDP","targetSecret":{"name":"portal-client-secret-organization-idp","namespace":"platform-mesh-system"},"tokenLifespan":3600}` | client configuration |
| keycloakConfig.client.name | string | `"organizationIDP"` | client name |
| keycloakConfig.client.targetSecret | object | `{"name":"portal-client-secret-organization-idp","namespace":"platform-mesh-system"}` | target secret options |
| keycloakConfig.client.targetSecret.name | string | `"portal-client-secret-organization-idp"` | secret name |
| keycloakConfig.client.targetSecret.namespace | string | `"platform-mesh-system"` | secret namespace |
| keycloakConfig.client.tokenLifespan | int | `3600` | token lifespan |
| keycloakConfig.url | string | `"http://openmfp-keycloak.openmfp-system.svc.cluster.local/keycloak"` | url of the keycloak server |

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
# organization-idp

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart to deploy organization identity provider in openmfp

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/openmfp/helm-charts | common | 0.5.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crossplane.client.displayName | string | `"ClientName"` | valid redirect uris for the client |
| crossplane.client.name | string | `"clientname"` | name of the client |
| crossplane.client.validRedirectUris[0] | string | `"http://localhost:8000/callback*"` | keycloak callback url |
| crossplane.client.validRedirectUris[1] | string | `"http://localhost:4300/callback*"` |  |
| crossplane.enabled | bool | `true` | toggle to enable/disable crossplane |
| crossplane.providerConfig.name | string | `"keycloak-provider-config"` | name of the client |
| crossplane.providerConfig.namespace | string | `"platform-mesh-system"` | client namespace |
| crossplane.realm | object | `{"accessTokenLifespan":"8h","displayName":"default","name":"default","registrationAllowed":true}` | crossplane realm config |
| crossplane.realm.accessTokenLifespan | string | `"8h"` | realm access token lifespan |
| crossplane.realm.displayName | string | `"default"` | realm display name |
| crossplane.realm.name | string | `"default"` | realm name |
| crossplane.realm.registrationAllowed | bool | `true` | realm registration allowed |
| crossplane.trustedAudiences | list | `[]` |  |
| keycloakConfig.client | object | `{"name":"organizationIDP","targetSecret":{"name":"portal-client-secret-organization-idp","namespace":"platform-mesh-system"},"tokenLifespan":3600}` | client configuration |
| keycloakConfig.client.name | string | `"organizationIDP"` | client name |
| keycloakConfig.client.targetSecret | object | `{"name":"portal-client-secret-organization-idp","namespace":"platform-mesh-system"}` | target secret options |
| keycloakConfig.client.targetSecret.name | string | `"portal-client-secret-organization-idp"` | secret name |
| keycloakConfig.client.targetSecret.namespace | string | `"platform-mesh-system"` | secret namespace |
| keycloakConfig.client.tokenLifespan | int | `3600` | token lifespan |
| keycloakConfig.url | string | `"http://openmfp-keycloak.openmfp-system.svc.cluster.local/keycloak"` | url of the keycloak server |

