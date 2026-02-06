# search-operator

A Helm chart for the Platform Mesh Search Operator

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Description

The search-operator watches resources across KCP workspaces and indexes them into OpenSearch for search functionality.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| image.name | string | `ghcr.io/platform-mesh/search-operator` | Container image |
| crds.enabled | bool | `false` | Enable CRDs sub-chart deployment |
| kubeconfigSecret | string | `""` | Secret containing KCP kubeconfig |
| opensearch.url | string | `http://opensearch...` | OpenSearch service URL |
| logLevel | string | `info` | Log level (debug, info, warn, error) |

## Dependencies

- `search-operator-crds` - KCP APIResourceSchemas
- `common` - Shared Helm templates
