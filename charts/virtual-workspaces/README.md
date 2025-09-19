# virtual-workspaces

A Helm chart to deploy platform-mesh virtual-workspaces

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/platform-mesh/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/common)|
| `oci://ghcr.io/platform-mesh/helm-charts` | `account-operator-crds` | The `account-operator-crds` chart provides CRDS introduced by the `account-operator`. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/account-operator-crds)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| authenticationKubeconfigSecretName | string | `"portal-kubeconfig"` |  |
| cert.duration | string | `"8760h0m0s"` | Certificate duration |
| cert.extraDnsNames | list | `["kcp.api.portal.dev.local"]` | Extra DNS names for the certificate |
| cert.issuer.kind | string | `"Issuer"` | Issuer reference |
| cert.issuer.name | string | `"root-server-ca"` | Issuer name |
| cert.key.algorithm | string | `"RSA"` | Key algorithm (e.g. RSA or ECDSA) |
| cert.key.size | int | `4096` | Key size (e.g. 2048, 3072, 4096 for RSA or 256, 384, 521 for ECDSA) |
| cert.renewBefore | string | `"168h0m0s"` | Certificate renew before |
| cert.secretName | string | `"virtual-workspaces-cert"` | Secret name to store the certificate |
| clientCASecretName | string | `"root-front-proxy-client-ca"` |  |
| deployment.accountEntityName | string | `"core_platform-mesh_io_account"` |  |
| deployment.contentForLabel | string | `"ui.platform-mesh.io/content-for"` |  |
| deployment.entityLabel | string | `"ui.platform-mesh.io/entity"` |  |
| deployment.mainEntityName | string | `"main"` |  |
| deployment.resourceSchemaExportName | string | `"core.platform-mesh.io"` |  |
| deployment.resourceSchemaName | string | `"v250704-6d57f16.contentconfigurations.ui.platform-mesh.io"` |  |
| deployment.resourceSchemaWorkspace | string | `"root:platform-mesh-system"` |  |
| deployment.serverUrl | string | `"https://frontproxy-front-proxy.platform-mesh-system:6443"` |  |
| image.name | string | `"ghcr.io/platform-mesh/virtual-workspaces"` | The image repository |
| kubeconfigSecretName | string | `"account-operator-kubeconfig"` |  |
| requestHeaderClientCASecretName | string | `"root-requestheader-client-ca"` |  |
| service.port | int | `8443` |  |
| virtualWorkspaceSecretName | string | `"virtual-workspaces-cert"` |  |

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
