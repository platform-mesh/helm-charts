# rebac-authz-webhook

A Helm chart for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| certManager.caSecretName | string | `"rebac-authz-webhook-webhook-ca"` |  |
| certManager.createCA | bool | `false` |  |
| certManager.dnsNames | list | `[]` |  |
| certManager.enabled | bool | `true` |  |
| certManager.ipAddresses[0] | string | `"10.96.86.219"` |  |
| health.port | int | `8081` |  |
| healthProbeBindAddress | string | `":8081"` |  |
| image.name | string | `"ghcr.io/openmfp/rebac-authz-webhook"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | string | `"github"` |  |
| istio.dnsNames | list | `[]` |  |
| istio.exposed | bool | `false` |  |
| kcp.kubeconfig.file | string | `"kubeconfig"` |  |
| kcp.kubeconfig.path | string | `"/etc/kcp-kubeconfig"` |  |
| kcp.kubeconfig.secret | string | `"rebac-authz-webhook-kubeconfig"` |  |
| logLevel | string | `"INFO"` |  |
| openfga.url | string | `"openmfp-openfga:8081"` |  |
| podLabels."networking.gardener.cloud/to-public-networks" | string | `"allowed"` |  |
| service.annotations | object | `{}` |  |
| service.clusterIP | string | `""` |  |
| service.labels."networking.resources.gardener.cloud/to-openfga-tcp-grpc" | string | `"allowed"` |  |
| service.metricsPort | int | `8080` |  |
| service.port | int | `9443` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `true` |  |
| serviceAccount.create | bool | `true` |  |
| serviceMonitor.enabled | bool | `false` |  |
| serviceMonitor.labels.prometheus | string | `"seed"` |  |

## Overriding Values

The values in the `defaults:` section can be reused from other charts by using the lookup function "common.getKeyValue". It implements lookup on three levels:

1. Looks for `keyOverride` in the chart's values.yaml
2. Looks for `global.key` in the chart's or parent chart's values.yaml
3. Uses the `key` in the chart's values.yaml
4. Uses the `common.defaults.key` value from the table below.

1 has precendence over 2 over 3 over 4 respectively. This approach allows for individual charts to have minimal configuration, while still being able to override parameters locally.

Example
```
1) .Values.deployment.resources.limits.memoryOveride =  4096MB
2) .Values.global.deployment.resources.limits.memory =  2048MB
3) .Values.deployment.resources.limits.memory =  1024MB
4) .Values.common.defaults.deployment.resources.limits.memory = default 512MB
```
