> [!WARNING]
> The charts in this repository are under development and not ready for productive use. They are in an alpha stage. That means APIs and concepts may change on short notice including breaking changes or complete removal of apis.

# charts
Helm charts repo

## MCP UI Demo

### Prerequisites
- Kubernetes cluster
- Helm v3
- Access to GitHub Container Registry (ghcr.io)

### Quick Update
To update an existing installation:
```bash
helm upgrade mcp-ui-demo ./mcp-ui-demo -n mcp-ui
```

### First Time Deployment

The chart will automatically create the `mcp-ui` namespace if it doesn't exist.

1. First, create the namespace and apply the GitHub registry secret:
```bash
kubectl create namespace mcp-ui
kubectl apply -f mcp-ui-demo/secret.yaml
```

2. Install/Upgrade the Helm chart:
```bash
helm upgrade --install mcp-ui-demo ./mcp-ui-demo -n mcp-ui
```

This will deploy the MCP UI Demo application in the `mcp-ui` namespace using the image from GitHub Container Registry with proper authentication.

Note: The secret.yaml contains GitHub registry credentials and is git-ignored to prevent committing sensitive information.
