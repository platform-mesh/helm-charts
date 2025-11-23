# platform-mesh-infra-components

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ocm.component.create | bool | `true` |  |
| ocm.component.name | string | `"platform-mesh"` |  |
| ocm.interval | string | `"3m"` |  |
| ocm.referencePath | list | `[]` |  |
| ocm.repo.create | bool | `true` |  |
| ocm.repo.name | string | `"platform-mesh"` |  |
| ocm.skipVerify | bool | `true` |  |
| services.gateway-api.enabled | bool | `true` |  |
| services.gateway-api.gitRepo | bool | `true` |  |
| services.gateway-api.kustomizationResource.enabled | bool | `true` |  |
| services.gateway-api.kustomizationResource.install.crds | string | `"Skip"` |  |
| services.gateway-api.kustomizationResource.path | string | `"./config/crd/experimental"` |  |
| services.gateway-api.path | string | `"charts"` |  |
| services.gateway-api.resourceName | string | `"crds"` |  |
| services.gateway-api.skipHelmRelease | bool | `true` |  |
| services.gateway-api.targetNamespace | string | `"default"` |  |
| services.gateway-api.values | object | `{}` |  |
| services.traefik.enabled | bool | `true` |  |
| services.traefik.helmRepo | bool | `true` |  |
| services.traefik.path | string | `"charts"` |  |
| services.traefik.resourceName | string | `"chart"` |  |
| services.traefik.targetNamespace | string | `"default"` |  |
| services.traefik.values.experimental.kubernetesGateway.enabled | bool | `true` |  |
| services.traefik.values.gateway.enabled | bool | `false` |  |
| services.traefik.values.gatewayClass.enabled | bool | `true` |  |
| services.traefik.values.ports.websecure.exposedPort | int | `8443` |  |
| services.traefik.values.ports.websecure.nodePort | int | `31000` |  |
| services.traefik.values.providers.kubernetesGateway.enabled | bool | `true` |  |
| services.traefik.values.providers.kubernetesGateway.experimentalChannel | bool | `true` |  |
| services.traefik.values.service.spec.clusterIP | string | `"10.96.188.4"` |  |
| services.traefik.values.service.type | string | `"NodePort"` |  |

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
