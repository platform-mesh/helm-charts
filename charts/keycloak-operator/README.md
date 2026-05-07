# keycloak-operator

Keycloak Operator for Kubernetes

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Updating CRDs

CRDs are not managed by Helm and must be updated manually when upgrading the operator version.
Use the provided script, passing the target Keycloak version:

```bash
hack/update-keycloak-crds.sh <version>
```

Example:

```bash
hack/update-keycloak-crds.sh 26.6.0
```

This fetches the CRD manifests from the [OperatorHub community-operators](https://github.com/k8s-operatorhub/community-operators) repository and writes them to `charts/keycloak-operator/crds/`.

## Requirements

| Repository | Name | Description | Sources |
|------------|------|-------------|---------|
| `oci://ghcr.io/platform-mesh/helm-charts` | `common` | The `common` chart is a library of common resources that are shared across all other charts in the repository. It has no templates, but provides helm template functions and [default values](https://github.com/platform-mesh/helm-charts/blob/main/charts/common/values.yaml) that can be used by other charts. |[source](https://github.com/platform-mesh/helm-charts/tree/main/charts/common)|
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| deployment.replicas | int | `1` |  |
| deployment.resources.limits.cpu | string | `"700m"` | CPU limit |
| deployment.resources.limits.memory | string | `"450Mi"` | Memory limit |
| deployment.resources.requests.cpu | string | `"300m"` | CPU request |
| deployment.resources.requests.memory | string | `"450Mi"` | Memory request |
| deployment.specTemplate.annotations | object | `{}` | Annotations for the pod template |
| deployment.specTemplate.labels | object | `{}` | Labels for the pod template |
| image.name | string | `"quay.io/keycloak/keycloak-operator"` | The image repository |
| image.tag | string | `"26.6.0"` | The image tag (defaults to appVersion) |
| keycloakImage.repository | string | `"ghcr.io/platform-mesh/custom-images/keycloak"` | The Keycloak image repository |
| keycloakImage.tag | string | `"v26.6.0"` | The Keycloak image tag (defaults to appVersion) |
| watchNamespaces | string | `""` | Namespace to watch for Keycloak CRs. Defaults to the release namespace. |

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
