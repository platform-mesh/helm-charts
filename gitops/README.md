# Platform Mesh GitOps installation

This directory is a Flux reconciliation payload for a local Kind Platform Mesh
installation. Once Flux is installed, Flux—not a bootstrap script or a series
of Helm commands—owns all Platform Mesh prerequisites, certificates, and the
Platform Mesh operator.

Creating a Kubernetes cluster and installing Flux cannot be GitOps operations:
there is no cluster-resident reconciler yet. After that one-time trust bootstrap,
the installation is fully declarative.

## Prerequisites

- A Kind cluster with port `8443` mapped to the Traefik NodePort. The inline
  configuration in [`../scriptless-install.md`](../scriptless-install.md) can
  create one without a checkout.
- Flux controllers installed in the cluster.
- A Git revision that contains both this `gitops/` directory and
  `charts/platform-mesh-operator`. Flux builds the PMO chart directly from
  that Git source.

## Bootstrap Flux once

Install Flux by your organization’s normal bootstrap method. The Git source
must already contain this `gitops/` directory before applying the root Flux
objects. The checked-in source points to the upstream `main` branch, so it is
appropriate only after this directory has been merged and published there:

```sh
kubectl apply -k https://github.com/platform-mesh/helm-charts//gitops
```

To install from an unmerged branch, first push the branch to a fork. Change
`spec.url` and `spec.ref.branch` in
`gitops/flux-system/platform-mesh-install.yaml` to that fork and branch, then
apply the local root Kustomization:

```sh
kubectl apply -k gitops/
```

For example, an already-created source can be corrected without recreating it:

```sh
kubectl -n flux-system patch gitrepository platform-mesh-install \
  --type=merge \
  -p='{"spec":{"url":"https://github.com/<owner>/<repository>","ref":{"branch":"<branch>"}}}'
```

Replace the placeholders with the repository and branch that contain your
`gitops/` directory. Flux will fetch the updated source and retry the
Kustomization automatically. For a custom domain or private configuration,
make those changes in the same fork before applying it.

## Reconciliation order

`flux-system/platform-mesh-install` fetches this repository and reconciles
three dependent Kustomizations:

1. `platform-mesh-prerequisites` installs the OCM controller and cert-manager.
2. `platform-mesh-certificates` creates the local CA and `domain-certificate`.
3. `platform-mesh` installs PMO, its profile, OCM resources, and the
   `PlatformMesh` custom resource. PMO then reconciles the remaining services.

The certificate layer is deliberately separate: PMO trusts `domain-certificate`
at startup, so applying its HelmRelease before the certificate exists creates a
startup race.

## Customization

For a different DNS name, update both:

- `certificates/certificates.yaml` (`commonName` and `dnsNames`);
- `platform-mesh/platform-mesh-operator.yaml`
  (`installation.baseDomain`).

The bundled self-signed issuer is for local Kind only. Use an organizational
issuer and keep credentials in SOPS, External Secrets, or an equivalent secret
controller for production.

## Observe progress

```sh
flux get kustomizations
flux get helmreleases -A
kubectl -n platform-mesh-system get platformmesh platform-mesh
```
