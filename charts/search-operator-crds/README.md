# search-operator-crds

KCP APIResourceSchemas for the Search Operator

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

## Description

This chart deploys the KCP APIResourceSchema for `SearchIndex` and extends the `core.platform-mesh.io` APIExport to include search functionality.

## Resources Created

- `APIResourceSchema` - Defines the SearchIndex resource schema for KCP
- `APIExport` - Extends the core.platform-mesh.io export with SearchIndex

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|

## Usage

This chart should be deployed to the KCP workspace where the search-operator runs, typically alongside other platform-mesh CRD charts.
