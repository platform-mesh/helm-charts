# fga-operator

A Helm chart for fga-operator

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| coreModule | string | `"module core\n\ntype user\n\ntype role\n  relations\n    define assignee: [user,user:*]\n\ntype account\n  relations\n\n    define parent: [account]\n    define owner: [role#assignee]\n    define member: [role#assignee] or owner\n\n    define get: member or get from parent\n    define update: member or update from parent\n    define delete: owner or delete from parent\n\n    define create_core_openmfp_org_accounts: member\n    define list_core_openmfp_org_accounts: member\n    define watch_core_openmfp_org_accounts: member\n\n    define member_manage: owner or owner from parent\n\n    # org and account specific\n    define watch: member or watch from parent\n\n    # org specific\n    define create: member or create from parent\n    define list: member or list from parent\n"` |  |
| crds.enabled | bool | `false` |  |
| deployment.resources.limits.cpu | string | `"260m"` |  |
| deployment.resources.limits.memory | string | `"512Mi"` |  |
| deployment.resources.requests.cpu | string | `"150m"` |  |
| deployment.resources.requests.memory | string | `"128Mi"` |  |
| deployment.revisionHistoryLimit | int | `3` |  |
| environment | string | `"local"` | environment indicator, used for logging and observability |
| fga.target | string | `"openmfp-openfga.openmfp-system.svc.cluster.local:8081"` |  |
| hostAliases.enabled | bool | `true` |  |
| hostAliases.items[0].hostnames[0] | string | `"kcp.dev.local"` |  |
| hostAliases.items[0].ip | string | `"10.96.0.100"` |  |
| image.name | string | `"ghcr.io/openmfp/fga-operator"` |  |
| initializer.kubeconfigSecret | string | `""` | The kubeconfig secret for the initializer |
| kubeconfigSecret | string | `""` | The kubeconfig secret for operator and generator |
| logLevel | string | `"info"` |  |
| region | string | `"local"` | region indicator, used for logging and observability |

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
