# example-kro-provider

Deploys the **kro-composition-operator** (KROaaS) as a Platform Mesh provider, the
httpbin-provider way. Unlike httpbin there is **no api-syncagent**: the operator is
kcp-native and composes provider APIs directly inside each consumer workspace.

Pulled in by the `example-data` overlay (gated behind `--example-data`), which also:

- adds a `kro-provider` **provider connection** (`adminAuth: true`) to the
  `PlatformMesh` CR — its kubeconfig lands in the `kro-provider-kubeconfig` secret
  this chart mounts (`kubeconfigSecret`); and
- adds `kro.run` to the **default API bindings** for `root:account`, so every
  Account can author `ResourceGraphDefinition`s.

The provider workspace bootstrap (APIExport / APIResourceSchema / ProviderMetadata /
ContentConfiguration, plus the `root:orgs` APIExportPolicy) is applied by
`scripts/start.sh` from `example-data/root/providers/kro-provider`.

## Contents

| File | Purpose |
|------|---------|
| `resources.yaml` | OCM chart + image `Resource`s from the `platform-mesh` component |
| `helmreleases.yaml` | Namespace + flux `HelmRelease` for the operator |
| `kustomization.yaml` | kustomize wiring |
