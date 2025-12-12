# platform-mesh-operator

A Helm chart to automate bootstrapping of new environment

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| crds.enabled | bool | `true` |  |
| deployment.replicas | int | `1` |  |
| extraArgs[0] | string | `"--subroutines-feature-toggles-enabled=true"` |  |
| image.name | string | `"ghcr.io/platform-mesh/platform-mesh-operator"` |  |
| istio.enabled | bool | `false` |  |
| log.level | string | `"debug"` |  |
| operator.leaderElect | bool | `true` |  |
| remoteFluxCD.enabled | bool | `false` | Enables reconciliation of PlatformMesh resources on remote clusters |
| remoteFluxCD.secretKey | string | `"kubeconfig"` |  |
| remoteFluxCD.secretName | string | `"platform-mesh-kubeconfig"` | Name of the secret containing the kubeconfig for remote cluster access where the PlatformMesh resources will be deployed |
| remotePlatformmesh.enabled | bool | `false` | Enables deployment to remote clusters. Set to true if the operator is not deployed on the same cluster where the FluxCD artefacts will be created. |
| remotePlatformmesh.fluxcd.secretKey | string | `"kubeconfig"` |  |
| remotePlatformmesh.fluxcd.secretName | string | `"platform-mesh-secret"` | Name of the secret located on the remote FluxCD cluster containing Platform Mesh kubeconfig |
| remotePlatformmesh.operator.secretKey | string | `"kubeconfig"` |  |
| remotePlatformmesh.operator.secretName | string | `"platform-mesh-secret"` | Name of the secret containing the kubeconfig for the cluster where the created FluxCD artefacts will be created. NOTE: target deployment will alway be same as the cluster where the Platform Mesh resource lives. |
| tracing.collector.endpoint | string | `"observability-opentelemetry-collector.observability.svc.cluster.local:4317"` |  |
| tracing.enabled | bool | `false` |  |

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
