# security-operator

A Helm chart for security-operator

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| baseDomain | string | `"portal.localhost:8443"` |  |
| caSecret | string | `""` |  |
| coreModule | string | `"\nmodule core\n\ntype user\n\ntype role\n  relations\n    define assignee: [user,user:*]\n\ntype core_platform-mesh_io_account\n  relations\n    define parent: [core_platform-mesh_io_account]\n\n    define owner: [role#assignee] or owner from parent\n    define member: [role#assignee] or owner or member from parent\n\n    define get: member\n    define update: member\n    define patch: member\n    define delete: owner\n\n    define create_core_platform-mesh_io_accounts: member\n    define list_core_platform-mesh_io_accounts: member\n    define watch_core_platform-mesh_io_accounts: member\n\n    # org and account specific\n    define watch: member\n\n    define create_core_platform-mesh_io_accountinfos: member\n    define list_core_platform-mesh_io_accountinfos: member\n    define watch_core_platform-mesh_io_accountinfos: member\n\n    define list_core_kcp_io_logicalclusters: member\n    define watch_core_kcp_io_logicalclusters: member\n\n    # IAM specific\n    define manage_iam_roles: owner\n    define get_iam_roles: member\n    define get_iam_users: member\n\ntype core_platform-mesh_io_accountinfo\n  relations\n    define parent: [core_platform-mesh_io_account]\n\n    define member: member from parent\n    define owner: owner from parent\n\n    define get: member\n    define watch: member\n\n    # IAM specific\n    define manage_iam_roles: owner\n    define get_iam_roles: member\n    define get_iam_users: member\n\ntype core_kcp_io_logicalcluster\n  relations\n    define parent: [core_platform-mesh_io_account]\n\n    define member: member from parent\n\n    define get: member\n    define watch: member"` |  |
| crds.enabled | bool | `false` |  |
| deployment.resources.limits.cpu | string | `"260m"` |  |
| deployment.resources.limits.memory | string | `"512Mi"` |  |
| deployment.resources.requests.cpu | string | `"150m"` |  |
| deployment.resources.requests.memory | string | `"128Mi"` |  |
| deployment.revisionHistoryLimit | int | `3` |  |
| environment | string | `"local"` | environment indicator, used for logging and observability |
| fga.extraArgs | list | `[]` |  |
| fga.inviteKeycloakBaseUrl | string | `""` |  |
| fga.setDefaultPassword | bool | `false` |  |
| fga.target | string | `"openfga.platform-mesh-system.svc.cluster.local:8081"` |  |
| generator.extraArgs | list | `[]` |  |
| hostAliases.enabled | bool | `false` |  |
| image.name | string | `"ghcr.io/platform-mesh/security-operator"` |  |
| initializer.extraArgs | list | `[]` |  |
| initializer.kubeconfigSecret | string | `""` | The kubeconfig secret for the initializer |
| keycloak.client.secret.key | string | `"attribute.client_secret"` |  |
| keycloak.client.secret.name | string | `"security-operator-client-secret"` |  |
| keycloakSecret | string | `"keycloak-admin"` |  |
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
