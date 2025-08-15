# security-operator

A Helm chart for security-operator

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| coreModule | string | `"\nmodule core\n\ntype user\n\ntype role\n  relations\n    define assignee: [user,user:*]\n\ntype core_platform-mesh_io_account\n  relations\n\n    define parent: [core_platform-mesh_io_account]\n    define owner: [role#assignee]\n    define member: [role#assignee] or owner\n\n    define get: member or get from parent\n    define update: member or update from parent\n    define delete: owner or delete from parent\n\n    define create_core_platform-mesh_io_accounts: member\n    define list_core_platform-mesh_io_accounts: member\n    define watch_core_platform-mesh_io_accounts: member\n\n    define member_manage: owner or owner from parent\n\n    # org and account specific\n    define watch: member or watch from parent\n\n    # org specific\n    define create: member or create from parent\n    define list: member or list from parent\n\n    define create_core_namespaces: member\n    define list_core_namespaces: member\n    define watch_core_namespaces: member\n\n    define create_core_platform-mesh_io_accountinfos: member\n    define list_core_platform-mesh_io_accountinfos: member\n    define watch_core_platform-mesh_io_accountinfos: member\n\n    define create_apis_kcp_io_apibindings: owner\n    define list__apis_kcp_io_apibindings: member\n    define watch_apis_kcp_io_apibindings: member\n\ntype core_namespace\n  relations\n    define parent: [core_platform-mesh_io_account]\n\n    define member: member from parent\n    define owner: owner from parent\n\n    define get: get from parent\n    define update: update from parent\n    define delete: delete from parent\n\n    # org and account specific\n    define watch: watch from parent\n\n    # org specific\n    define create: create from parent\n    define list: list from parent\n\ntype core_platform-mesh_io_accountinfo\n  relations\n\n    define parent: [core_platform-mesh_io_account]\n\n    define get: get from parent\n    define update: update from parent\n    define delete: delete from parent\n\n    # org and account specific\n    define watch: watch from parent\n\n    # org specific\n    define create: create from parent\n    define list: list from parent\n\n  type apis_kcp_io_apibinding\n    relations\n      define parent: [core_platform-mesh_io_account]\n\n      define get: member from parent\n      define update: member from parent\n      define delete: owner from parent\n      define watch: member from parent"` |  |
| crds.enabled | bool | `false` |  |
| deployment.resources.limits.cpu | string | `"260m"` |  |
| deployment.resources.limits.memory | string | `"512Mi"` |  |
| deployment.resources.requests.cpu | string | `"150m"` |  |
| deployment.resources.requests.memory | string | `"128Mi"` |  |
| deployment.revisionHistoryLimit | int | `3` |  |
| environment | string | `"local"` | environment indicator, used for logging and observability |
| fga.target | string | `"openfga.platform-mesh-system.svc.cluster.local:8081"` |  |
| hostAliases.enabled | bool | `true` |  |
| hostAliases.items[0].hostnames[0] | string | `"kcp.dev.local"` |  |
| hostAliases.items[0].ip | string | `"10.96.0.100"` |  |
| image.name | string | `"ghcr.io/platform-mesh/security-operator"` |  |
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

1 has precedence over 2 over 3 over 4 respectively. This approach allows for individual charts to have minimal configuration, while still being able to override parameters locally.

Example
```
1) .Values.deployment.resources.limits.memoryOverride = 4096MB
2) .Values.global.deployment.resources.limits.memory = 2048MB
3) .Values.deployment.resources.limits.memory = 1024MB
4) .Values.common.defaults.deployment.resources.limits.memory = default 512MB
```
