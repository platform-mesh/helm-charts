# Platform Mesh installation

Platform Mesh is installed declaratively by Helm. The Helm release contains the
Platform Mesh operator, its CRDs, the OCM repository and component, the signed
default profile, and the `PlatformMesh` resource. The operator reconciles the
remaining Platform Mesh services. No repository checkout, bootstrap script, KRO,
or imperative secret-generation step is part of this flow.

## Prerequisites

- Kubernetes 1.28+
- [Flux](https://fluxcd.io) 2.17.0, including the source and Helm controllers
- [OCM Kubernetes controller](https://github.com/open-component-model/kubernetes)
- A wildcard TLS certificate covering `<base-domain>` and `*.<base-domain>`,
  provided as `domain-certificate` and `domain-certificate-ca` in the target
  namespace. These can be managed by cert-manager, External Secrets, or your
  existing GitOps configuration.

Install Flux and the OCM controller using their published, declarative
manifests before installing Platform Mesh. They are cluster prerequisites and
are deliberately not hidden behind another wrapper chart.

## Install

Create a small values file in your GitOps repository:

```yaml
# platform-mesh-values.yaml
installation:
  enabled: true
  baseDomain: platform.example.com
  version: 0.5.2
```

Install the published operator chart (or reference the same chart from a Flux
`HelmRelease`):

```bash
helm upgrade --install platform-mesh-operator \
  oci://ghcr.io/platform-mesh/helm-charts/platform-mesh-operator \
  --namespace platform-mesh-system --create-namespace \
  --values platform-mesh-values.yaml
```

The only required Platform Mesh setting is `installation.baseDomain`. Pin
`installation.version` for reproducible GitOps deployments; it selects the
signed Platform Mesh OCM component.

The TLS secrets are intentionally external inputs. For example, cert-manager
may create `domain-certificate`; publish the CA bundle as
`domain-certificate-ca`. Do not put private keys or generated passwords in this
chart's values.

## Verify and DNS

Wait for the operator to report the installation ready:

```bash
kubectl get platformmesh -n platform-mesh-system platform-mesh
kubectl get helmrelease -n platform-mesh-system
```

Point both records to the Traefik LoadBalancer address:

```text
<base-domain>.   A  300  <LoadBalancer-IP>
*.<base-domain> A  300  <LoadBalancer-IP>
```

The chart's `installation.enabled` option is off by default because the same
operator chart is also used where a separate GitOps repository owns the
`PlatformMesh` resource and profile.
