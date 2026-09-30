# Scriptless Platform Mesh installation

This installs Platform Mesh without a bootstrap script. A Kubernetes cluster,
Flux, and the OCM Kubernetes controller are prerequisites.

## Prerequisites

### Kind cluster

Create a Kind cluster before following this guide. For local Platform Mesh, it
must expose Traefik's HTTPS NodePort on `127.0.0.1:8443` (host port `8443` to
node port `31000`). The cluster creation method is intentionally outside this
installation flow.

### Flux

```shell
helm upgrade --install flux \
  oci://ghcr.io/fluxcd-community/charts/flux2 \
  --namespace flux-system \
  --create-namespace \
  --version 2.17.2 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set notificationController.create=false \
  --set-json 'helmController.container.additionalArgs=["--concurrent=50"]' \
  --set-json 'sourceController.container.additionalArgs=["--requeue-dependency=5s"]'
```

### OCM Kubernetes controller

Install the pinned controller chart directly from its public OCI registry. This
does not depend on a checkout or on an unpublished Platform Mesh manifest.

```shell
helm upgrade --install ocm-k8s-toolkit \
  oci://ghcr.io/open-component-model/kubernetes/controller/chart \
  --namespace ocm-system \
  --create-namespace \
  --version 0.13.0 \
  --set manager.concurrency.resource=3
```

## 1. Install Platform Mesh

The operator chart is temporarily installed from the local checkout because it
is not published yet. The Kind-only certificate chart in the next step is the
only other local resource used by this guide.

```shell
base_domain=portal.localhost
platform_mesh_version=0.5.2

helm upgrade --install platform-mesh-operator \
  ./charts/platform-mesh-operator \
  --namespace platform-mesh-system \
  --create-namespace \
  --set installation.enabled=true \
  --set installation.baseDomain="${base_domain}" \
  --set installation.version="${platform_mesh_version}"
```

`installation.baseDomain` is the required Platform Mesh setting. Pin
`installation.version` to select a reproducible signed OCM component version.
The Helm release installs the operator, its CRDs, the OCM repository and
component, OCM signature certificate, default Platform Mesh profile, and the
`PlatformMesh` resource. KRO and bootstrap scripts are not used.
The local kind profile exposes HTTPS through `https://<base-domain>:8443`.

## 2. Create local Gateway certificates

The Platform Mesh profile installs cert-manager. Once its Helm release is ready,
install the local Kind-only certificate chart. It creates a self-signed CA in
`domain-certificate-ca` and a TLS certificate in `domain-certificate`, covering
both `${base_domain}` and `*.${base_domain}`. cert-manager places the issuing
CA in the leaf certificate's `ca.crt`; Platform Mesh and the Gateway consume
the `domain-certificate` Secret automatically.

This chart is intentionally local and is not part of the published Platform Mesh
component. Self-signed certificates are suitable for local Kind only; use your
organization's cert-manager issuer or external certificate management in
production.

```shell
until kubectl get --namespace platform-mesh-system helmrelease/cert-manager >/dev/null 2>&1; do
  sleep 2
done

kubectl wait --namespace platform-mesh-system \
  --for=condition=ready helmrelease/cert-manager \
  --timeout=15m

helm upgrade --install platform-mesh-kind-certificates \
  ./charts/platform-mesh-kind-certificates \
  --create-namespace \
  --namespace platform-mesh-system \
  --set-json 'dnsNames=["'"${base_domain}"'","*.'"${base_domain}"'"]'

kubectl wait --namespace platform-mesh-system \
  --for=condition=ready certificate/platform-mesh-gateway \
  --timeout=5m

# Restart PMO so Go reloads its system trust store with the generated CA.
kubectl rollout restart --namespace platform-mesh-system deployment/platform-mesh-operator
kubectl rollout status --namespace platform-mesh-system deployment/platform-mesh-operator --timeout=5m
```

## 3. Verify and configure DNS

Wait for the Platform Mesh resource and its managed Helm releases to reconcile:

```shell
kubectl get platformmesh --namespace platform-mesh-system platform-mesh
kubectl get helmrelease --namespace platform-mesh-system
```

For Kind, map the base domain and wildcard domain to `127.0.0.1` (for example,
with a DNS server that supports wildcard records). HTTPS is exposed at port
`8443`; the Traefik Service is deliberately a `NodePort`, not a LoadBalancer.
