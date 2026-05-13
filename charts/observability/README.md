# observability

OpenTelemetry-based observability stack for platform-mesh

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
## Values
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| createNamespace | bool | `false` | Create the namespace if it doesn't exist (usually handled externally) |
| httproutes | object | `{"gatewayName":"","gatewayNamespace":"","otelCollector":{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/otel","port":8888},"prometheus":{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/prometheus"}}` | ---------------------------------------------------------------------------- |
| httproutes.gatewayName | string | `""` | Name of the Gateway to attach routes to |
| httproutes.gatewayNamespace | string | `""` | Namespace of the Gateway (optional, defaults to same namespace) |
| httproutes.otelCollector | object | `{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/otel","port":8888}` | OpenTelemetry Collector HTTPRoute |
| httproutes.otelCollector.enabled | bool | `false` | Enable HTTPRoute for OTel Collector |
| httproutes.otelCollector.filters | list | `[]` | Optional filters |
| httproutes.otelCollector.hostnames | list | `[]` | Hostnames for the OTel Collector |
| httproutes.otelCollector.pathPrefix | string | `"/otel"` | Path prefix for OTel Collector |
| httproutes.otelCollector.port | int | `8888` | Port to expose (metrics port 8888 or receiver ports like 4318 for OTLP HTTP) |
| httproutes.prometheus | object | `{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/prometheus"}` | Prometheus UI HTTPRoute |
| httproutes.prometheus.enabled | bool | `false` | Enable HTTPRoute for Prometheus |
| httproutes.prometheus.filters | list | `[]` | Optional filters (e.g., URLRewrite for path stripping) |
| httproutes.prometheus.hostnames | list | `[]` | Hostnames for the Prometheus UI |
| httproutes.prometheus.pathPrefix | string | `"/prometheus"` | Path prefix for Prometheus UI |
| opentelemetry-operator | object | `{"enabled":true,"manager":{"collectorImage":{"repository":"otel/opentelemetry-collector-contrib"}}}` | ---------------------------------------------------------------------------- |
| opentelemetry-operator.enabled | bool | `true` | Enable the OpenTelemetry Operator |
| opentelemetry-operator.manager.collectorImage.repository | string | `"otel/opentelemetry-collector-contrib"` | Use the contrib image which includes the prometheus receiver |
| otelCollector | object | `{"config":{"batchTimeout":"10s"},"mode":"statefulset","name":"otel-gateway","replicas":1}` | ---------------------------------------------------------------------------- |
| otelCollector.config.batchTimeout | string | `"10s"` | Batch processor timeout before sending metrics |
| otelCollector.mode | string | `"statefulset"` | Deployment mode (statefulset required for Target Allocator) |
| otelCollector.name | string | `"otel-gateway"` | Name of the OpenTelemetryCollector CR |
| otelCollector.replicas | int | `1` | Number of collector replicas |
| prometheus | object | `{"alertmanager":{"enabled":false},"enabled":true,"kube-state-metrics":{"enabled":false},"prometheus-node-exporter":{"enabled":false},"prometheus-pushgateway":{"enabled":false},"server":{"extraFlags":["web.enable-remote-write-receiver","web.enable-lifecycle"],"persistentVolume":{"enabled":false},"service":{"type":"ClusterIP"}}}` | ---------------------------------------------------------------------------- |
| prometheus.alertmanager | object | `{"enabled":false}` | Disable components not needed for this POC |
| prometheus.enabled | bool | `true` | Enable Prometheus deployment |
| prometheus.server.extraFlags[0] | string | `"web.enable-remote-write-receiver"` | Enable remote write receiver (required for OTel Collector to push metrics) |
| prometheus.server.extraFlags[1] | string | `"web.enable-lifecycle"` | Enable lifecycle API (required for config reloader sidecar) |
| prometheus.server.persistentVolume.enabled | bool | `false` | Disable persistence for local development |
| serviceMonitors | object | `{"accountOperator":{"enabled":true,"labels":{"app":"account-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"},"kcp":{"enabled":true,"kubeconfig":{"groups":["system:monitoring"],"name":"metrics-viewer","secretName":"kubeconfig-metrics-viewer","username":"metrics-viewer","validity":"8766h"},"labels":{"app.kubernetes.io/component":"rootshard","app.kubernetes.io/name":"kcp"},"namespace":"platform-mesh-system","path":"/clusters/root/metrics","port":"https","scheme":"https","tlsInsecureSkipVerify":true,"tlsSecretName":"kcp-metrics-client-cert"},"openfga":{"enabled":true,"labels":{"app.kubernetes.io/name":"openfga"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"},"securityOperator":{"enabled":true,"labels":{"app":"security-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}}` | ---------------------------------------------------------------------------- |
| serviceMonitors.accountOperator | object | `{"enabled":true,"labels":{"app":"account-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}` | account-operator metrics scraping |
| serviceMonitors.accountOperator.enabled | bool | `true` | Enable scraping account-operator |
| serviceMonitors.accountOperator.labels | object | `{"app":"account-operator"}` | Labels to select account-operator metrics service |
| serviceMonitors.accountOperator.namespace | string | `"platform-mesh-system"` | Namespace where account-operator runs |
| serviceMonitors.accountOperator.path | string | `"/metrics"` | Path to metrics endpoint |
| serviceMonitors.accountOperator.port | string | `"metrics"` | Name of the port exposing metrics |
| serviceMonitors.kcp | object | `{"enabled":true,"kubeconfig":{"groups":["system:monitoring"],"name":"metrics-viewer","secretName":"kubeconfig-metrics-viewer","username":"metrics-viewer","validity":"8766h"},"labels":{"app.kubernetes.io/component":"rootshard","app.kubernetes.io/name":"kcp"},"namespace":"platform-mesh-system","path":"/clusters/root/metrics","port":"https","scheme":"https","tlsInsecureSkipVerify":true,"tlsSecretName":"kcp-metrics-client-cert"}` | kcp (root shard) metrics scraping Requires client certificate authentication |
| serviceMonitors.kcp.enabled | bool | `true` | Enable scraping kcp |
| serviceMonitors.kcp.kubeconfig | object | `{"groups":["system:monitoring"],"name":"metrics-viewer","secretName":"kubeconfig-metrics-viewer","username":"metrics-viewer","validity":"8766h"}` | Kubeconfig configuration for kcp authentication The kcp-operator creates a kubeconfig with client certificates |
| serviceMonitors.kcp.kubeconfig.groups | list | `["system:monitoring"]` | Groups embedded in the client certificate system:monitoring grants read access to /clusters/root/metrics endpoints |
| serviceMonitors.kcp.kubeconfig.name | string | `"metrics-viewer"` | Name of the Kubeconfig CR to create |
| serviceMonitors.kcp.kubeconfig.secretName | string | `"kubeconfig-metrics-viewer"` | Name of the secret where kcp-operator stores the kubeconfig |
| serviceMonitors.kcp.kubeconfig.username | string | `"metrics-viewer"` | Username embedded in the client certificate |
| serviceMonitors.kcp.kubeconfig.validity | string | `"8766h"` | Validity period of the client certificate |
| serviceMonitors.kcp.labels | object | `{"app.kubernetes.io/component":"rootshard","app.kubernetes.io/name":"kcp"}` | Labels to select kcp service |
| serviceMonitors.kcp.namespace | string | `"platform-mesh-system"` | Namespace where kcp runs |
| serviceMonitors.kcp.path | string | `"/clusters/root/metrics"` | Path to metrics endpoint (kcp-specific path) |
| serviceMonitors.kcp.port | string | `"https"` | Name of the port exposing metrics (same as API port) |
| serviceMonitors.kcp.scheme | string | `"https"` | Use HTTPS scheme |
| serviceMonitors.kcp.tlsInsecureSkipVerify | bool | `true` | Skip TLS certificate verification (required for self-signed certs) |
| serviceMonitors.kcp.tlsSecretName | string | `"kcp-metrics-client-cert"` | Name of the TLS secret containing client cert/key for authentication This secret is created by the kcp-metrics-cert-job from the kubeconfig |
| serviceMonitors.openfga | object | `{"enabled":true,"labels":{"app.kubernetes.io/name":"openfga"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}` | OpenFGA metrics scraping |
| serviceMonitors.openfga.enabled | bool | `true` | Enable scraping OpenFGA |
| serviceMonitors.openfga.labels | object | `{"app.kubernetes.io/name":"openfga"}` | Labels to select OpenFGA service |
| serviceMonitors.openfga.namespace | string | `"platform-mesh-system"` | Namespace where OpenFGA runs |
| serviceMonitors.openfga.path | string | `"/metrics"` | Path to metrics endpoint |
| serviceMonitors.openfga.port | string | `"metrics"` | Name of the port exposing metrics |
| serviceMonitors.securityOperator | object | `{"enabled":true,"labels":{"app":"security-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}` | security-operator metrics scraping |
| serviceMonitors.securityOperator.enabled | bool | `true` | Enable scraping security-operator |
| serviceMonitors.securityOperator.labels | object | `{"app":"security-operator"}` | Labels to select security-operator metrics service |
| serviceMonitors.securityOperator.namespace | string | `"platform-mesh-system"` | Namespace where security-operator runs |
| serviceMonitors.securityOperator.path | string | `"/metrics"` | Path to metrics endpoint |
| serviceMonitors.securityOperator.port | string | `"metrics"` | Name of the port exposing metrics |

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
# observability

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.0](https://img.shields.io/badge/AppVersion-0.0.0-informational?style=flat-square)

OpenTelemetry-based observability stack for platform-mesh

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-operator | 0.112.0 |
| https://prometheus-community.github.io/helm-charts | prometheus | 29.6.0 |
| https://prometheus-community.github.io/helm-charts | prometheus-operator-crds | 19.1.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| createNamespace | bool | `false` | Create the namespace if it doesn't exist (usually handled externally) |
| httproutes | object | `{"gatewayName":"","gatewayNamespace":"","otelCollector":{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/otel","port":8888},"prometheus":{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/prometheus"}}` | ---------------------------------------------------------------------------- |
| httproutes.gatewayName | string | `""` | Name of the Gateway to attach routes to |
| httproutes.gatewayNamespace | string | `""` | Namespace of the Gateway (optional, defaults to same namespace) |
| httproutes.otelCollector | object | `{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/otel","port":8888}` | OpenTelemetry Collector HTTPRoute |
| httproutes.otelCollector.enabled | bool | `false` | Enable HTTPRoute for OTel Collector |
| httproutes.otelCollector.filters | list | `[]` | Optional filters |
| httproutes.otelCollector.hostnames | list | `[]` | Hostnames for the OTel Collector |
| httproutes.otelCollector.pathPrefix | string | `"/otel"` | Path prefix for OTel Collector |
| httproutes.otelCollector.port | int | `8888` | Port to expose (metrics port 8888 or receiver ports like 4318 for OTLP HTTP) |
| httproutes.prometheus | object | `{"enabled":false,"filters":[],"hostnames":[],"pathPrefix":"/prometheus"}` | Prometheus UI HTTPRoute |
| httproutes.prometheus.enabled | bool | `false` | Enable HTTPRoute for Prometheus |
| httproutes.prometheus.filters | list | `[]` | Optional filters (e.g., URLRewrite for path stripping) |
| httproutes.prometheus.hostnames | list | `[]` | Hostnames for the Prometheus UI |
| httproutes.prometheus.pathPrefix | string | `"/prometheus"` | Path prefix for Prometheus UI |
| opentelemetry-operator | object | `{"enabled":true,"manager":{"collectorImage":{"repository":"otel/opentelemetry-collector-contrib"}}}` | ---------------------------------------------------------------------------- |
| opentelemetry-operator.enabled | bool | `true` | Enable the OpenTelemetry Operator |
| opentelemetry-operator.manager.collectorImage.repository | string | `"otel/opentelemetry-collector-contrib"` | Use the contrib image which includes the prometheus receiver |
| otelCollector | object | `{"config":{"batchTimeout":"10s"},"mode":"statefulset","name":"otel-gateway","replicas":1}` | ---------------------------------------------------------------------------- |
| otelCollector.config.batchTimeout | string | `"10s"` | Batch processor timeout before sending metrics |
| otelCollector.mode | string | `"statefulset"` | Deployment mode (statefulset required for Target Allocator) |
| otelCollector.name | string | `"otel-gateway"` | Name of the OpenTelemetryCollector CR |
| otelCollector.replicas | int | `1` | Number of collector replicas |
| prometheus | object | `{"alertmanager":{"enabled":false},"enabled":true,"kube-state-metrics":{"enabled":false},"prometheus-node-exporter":{"enabled":false},"prometheus-pushgateway":{"enabled":false},"server":{"extraFlags":["web.enable-remote-write-receiver","web.enable-lifecycle"],"persistentVolume":{"enabled":false},"service":{"type":"ClusterIP"}}}` | ---------------------------------------------------------------------------- |
| prometheus.alertmanager | object | `{"enabled":false}` | Disable components not needed for this POC |
| prometheus.enabled | bool | `true` | Enable Prometheus deployment |
| prometheus.server.extraFlags[0] | string | `"web.enable-remote-write-receiver"` | Enable remote write receiver (required for OTel Collector to push metrics) |
| prometheus.server.extraFlags[1] | string | `"web.enable-lifecycle"` | Enable lifecycle API (required for config reloader sidecar) |
| prometheus.server.persistentVolume.enabled | bool | `false` | Disable persistence for local development |
| serviceMonitors | object | `{"accountOperator":{"enabled":true,"labels":{"app":"account-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"},"kcp":{"enabled":true,"kubeconfig":{"groups":["system:monitoring"],"name":"metrics-viewer","secretName":"kubeconfig-metrics-viewer","username":"metrics-viewer","validity":"8766h"},"labels":{"app.kubernetes.io/component":"rootshard","app.kubernetes.io/name":"kcp"},"namespace":"platform-mesh-system","path":"/clusters/root/metrics","port":"https","scheme":"https","tlsInsecureSkipVerify":true,"tlsSecretName":"kcp-metrics-client-cert"},"openfga":{"enabled":true,"labels":{"app.kubernetes.io/name":"openfga"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"},"securityOperator":{"enabled":true,"labels":{"app":"security-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}}` | ---------------------------------------------------------------------------- |
| serviceMonitors.accountOperator | object | `{"enabled":true,"labels":{"app":"account-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}` | account-operator metrics scraping |
| serviceMonitors.accountOperator.enabled | bool | `true` | Enable scraping account-operator |
| serviceMonitors.accountOperator.labels | object | `{"app":"account-operator"}` | Labels to select account-operator metrics service |
| serviceMonitors.accountOperator.namespace | string | `"platform-mesh-system"` | Namespace where account-operator runs |
| serviceMonitors.accountOperator.path | string | `"/metrics"` | Path to metrics endpoint |
| serviceMonitors.accountOperator.port | string | `"metrics"` | Name of the port exposing metrics |
| serviceMonitors.kcp | object | `{"enabled":true,"kubeconfig":{"groups":["system:monitoring"],"name":"metrics-viewer","secretName":"kubeconfig-metrics-viewer","username":"metrics-viewer","validity":"8766h"},"labels":{"app.kubernetes.io/component":"rootshard","app.kubernetes.io/name":"kcp"},"namespace":"platform-mesh-system","path":"/clusters/root/metrics","port":"https","scheme":"https","tlsInsecureSkipVerify":true,"tlsSecretName":"kcp-metrics-client-cert"}` | kcp (root shard) metrics scraping Requires client certificate authentication |
| serviceMonitors.kcp.enabled | bool | `true` | Enable scraping kcp |
| serviceMonitors.kcp.kubeconfig | object | `{"groups":["system:monitoring"],"name":"metrics-viewer","secretName":"kubeconfig-metrics-viewer","username":"metrics-viewer","validity":"8766h"}` | Kubeconfig configuration for kcp authentication The kcp-operator creates a kubeconfig with client certificates |
| serviceMonitors.kcp.kubeconfig.groups | list | `["system:monitoring"]` | Groups embedded in the client certificate system:monitoring grants read access to /clusters/root/metrics endpoints |
| serviceMonitors.kcp.kubeconfig.name | string | `"metrics-viewer"` | Name of the Kubeconfig CR to create |
| serviceMonitors.kcp.kubeconfig.secretName | string | `"kubeconfig-metrics-viewer"` | Name of the secret where kcp-operator stores the kubeconfig |
| serviceMonitors.kcp.kubeconfig.username | string | `"metrics-viewer"` | Username embedded in the client certificate |
| serviceMonitors.kcp.kubeconfig.validity | string | `"8766h"` | Validity period of the client certificate |
| serviceMonitors.kcp.labels | object | `{"app.kubernetes.io/component":"rootshard","app.kubernetes.io/name":"kcp"}` | Labels to select kcp service |
| serviceMonitors.kcp.namespace | string | `"platform-mesh-system"` | Namespace where kcp runs |
| serviceMonitors.kcp.path | string | `"/clusters/root/metrics"` | Path to metrics endpoint (kcp-specific path) |
| serviceMonitors.kcp.port | string | `"https"` | Name of the port exposing metrics (same as API port) |
| serviceMonitors.kcp.scheme | string | `"https"` | Use HTTPS scheme |
| serviceMonitors.kcp.tlsInsecureSkipVerify | bool | `true` | Skip TLS certificate verification (required for self-signed certs) |
| serviceMonitors.kcp.tlsSecretName | string | `"kcp-metrics-client-cert"` | Name of the TLS secret containing client cert/key for authentication This secret is created by the kcp-metrics-cert-job from the kubeconfig |
| serviceMonitors.openfga | object | `{"enabled":true,"labels":{"app.kubernetes.io/name":"openfga"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}` | OpenFGA metrics scraping |
| serviceMonitors.openfga.enabled | bool | `true` | Enable scraping OpenFGA |
| serviceMonitors.openfga.labels | object | `{"app.kubernetes.io/name":"openfga"}` | Labels to select OpenFGA service |
| serviceMonitors.openfga.namespace | string | `"platform-mesh-system"` | Namespace where OpenFGA runs |
| serviceMonitors.openfga.path | string | `"/metrics"` | Path to metrics endpoint |
| serviceMonitors.openfga.port | string | `"metrics"` | Name of the port exposing metrics |
| serviceMonitors.securityOperator | object | `{"enabled":true,"labels":{"app":"security-operator"},"namespace":"platform-mesh-system","path":"/metrics","port":"metrics"}` | security-operator metrics scraping |
| serviceMonitors.securityOperator.enabled | bool | `true` | Enable scraping security-operator |
| serviceMonitors.securityOperator.labels | object | `{"app":"security-operator"}` | Labels to select security-operator metrics service |
| serviceMonitors.securityOperator.namespace | string | `"platform-mesh-system"` | Namespace where security-operator runs |
| serviceMonitors.securityOperator.path | string | `"/metrics"` | Path to metrics endpoint |
| serviceMonitors.securityOperator.port | string | `"metrics"` | Name of the port exposing metrics |

