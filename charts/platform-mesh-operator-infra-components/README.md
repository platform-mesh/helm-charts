# platform-mesh-operator-infra-components

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| certManager.enabled | bool | `true` |  |
| certManager.interval | string | `"1m"` |  |
| certManager.name | string | `"cert-manager"` |  |
| certManager.ocmResourceName | string | `"chart"` |  |
| certManager.targetNamespace | string | `"default"` |  |
| certManager.values.crds.enabled | bool | `true` |  |
| fluxCD.kubeConfig.enabled | bool | `false` | If set, all created FluxCD resources will deploy to a remote cluster using this kubeconfig. |
| fluxCD.kubeConfig.secretRef.key | string | `"kubeconfig"` |  |
| fluxCD.kubeConfig.secretRef.name | string | `"platform-mesh-kubeconfig"` | name of the secret containing the kubeconfig |
| gatewayApi.enabled | bool | `true` |  |
| gatewayApi.kustomization.install.crds | string | `"Skip"` |  |
| gatewayApi.kustomization.interval | string | `"1m"` |  |
| gatewayApi.kustomization.path | string | `"./config/crd/experimental"` |  |
| gatewayApi.name | string | `"gateway-api"` |  |
| gatewayApi.ocmResourceName | string | `"crds"` |  |
| ocm.component.name | string | `"platform-mesh"` |  |
| ocm.interval | string | `"3m"` |  |
| ocm.referencePath | list | `[]` |  |
| ocm.repo.name | string | `"platform-mesh"` |  |
| ocm.skipVerify | bool | `true` |  |
| timeout | string | `"30m"` |  |
| traefik.chart.name | string | `"traefik"` |  |
| traefik.enabled | bool | `true` |  |
| traefik.interval | string | `"1m"` |  |
| traefik.name | string | `"traefik"` |  |
| traefik.ocmResourceName | string | `"chart"` |  |
| traefik.targetNamespace | string | `"default"` |  |
| traefik.values.experimental.kubernetesGateway.enabled | bool | `true` |  |
| traefik.values.gateway.enabled | bool | `false` |  |
| traefik.values.gatewayClass.enabled | bool | `true` |  |
| traefik.values.ports.websecure.exposedPort | int | `8443` |  |
| traefik.values.ports.websecure.nodePort | int | `31000` |  |
| traefik.values.providers.kubernetesGateway.enabled | bool | `true` |  |
| traefik.values.providers.kubernetesGateway.experimentalChannel | bool | `true` |  |
| traefik.values.service.spec.clusterIP | string | `"10.96.188.4"` |  |
| traefik.values.service.type | string | `"NodePort"` |  |
| traefikCRDs.chart.name | string | `"traefik-crds"` |  |
| traefikCRDs.enabled | bool | `true` |  |
| traefikCRDs.interval | string | `"1m"` |  |
| traefikCRDs.name | string | `"traefik-crds"` |  |
| traefikCRDs.ocmComponentName | string | `"traefik"` |  |
| traefikCRDs.ocmResourceName | string | `"crds"` |  |
| traefikCRDs.targetNamespace | string | `"default"` |  |

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
