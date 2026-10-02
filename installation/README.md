# Local Kind installation

This guide installs Platform Mesh on a local Kind cluster from this checkout.
It uses the `kind` PMO profile and the bundled prerequisites chart. It is not a
production installation guide.

## Requirements

- `kind`, `kubectl`, and Helm.
- A Kind cluster whose `127.0.0.1:8443` host port is mapped to Traefik's
  NodePort `31000`.
- A Platform Mesh OCM component version available to the configured registry.

The cluster itself must exist before Helm can install anything into it.

## Install prerequisites

The prerequisites chart installs the local controllers required by the Kind
profile: Flux, the OCM Kubernetes controller, cert-manager, Gateway API CRDs,
Traefik, CloudNativePG, and the Keycloak Operator. Helm discovers CRDs before
rendering custom resources, so install it twice: first for controllers and
CRDs, then for Traefik and the local Gateway certificate.

```shell
set -euo pipefail

base_domain=portal.localhost

helm upgrade --install platform-mesh-prerequisites \
  ./charts/platform-mesh-prerequisites \
  --namespace platform-mesh-system \
  --create-namespace \
  --wait \
  --timeout 15m

kubectl wait --namespace platform-mesh-system \
  --for=condition=Available deployment/platform-mesh-prerequisites-cert-manager \
  --timeout=5m

helm upgrade platform-mesh-prerequisites \
  ./charts/platform-mesh-prerequisites \
  --namespace platform-mesh-system \
  --reuse-values \
  --wait \
  --timeout 15m \
  --set traefik.enabled=true \
  --set localCertificates.enabled=true \
  --set-json 'localCertificates.dnsNames=["'"${base_domain}"'","*.'"${base_domain}"'"]'

kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready certificate/platform-mesh-gateway \
  --timeout=5m
```

## Install Platform Mesh

```shell
platform_mesh_version=0.6.0-build.6

helm upgrade --install platform-mesh-operator \
  ./charts/platform-mesh-operator \
  --namespace platform-mesh-system \
  --set installation.enabled=true \
  --set installation.profile=kind \
  --set installation.baseDomain="${base_domain}" \
  --set installation.version="${platform_mesh_version}" \
  --wait \
  --timeout 15m

kubectl wait --namespace platform-mesh-system \
  --for=condition=Ready platformmeshes/platform-mesh \
  --timeout=30m
```

The PMO release creates the Platform Mesh profile, OCM resources, and the
`PlatformMesh` resource. PMO then reconciles the Platform Mesh services.

## Verify

```shell
kubectl wait --namespace platform-mesh-system --for=condition=ready platformmeshes/platform-mesh --timeout=10m
```

The local endpoint is `https://${base_domain}:8443`. The bundled certificate is
self-signed; trust its CA from `domain-certificate-ca` in your local client.
