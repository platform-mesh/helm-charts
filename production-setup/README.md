# Platform Mesh — Production Setup

This directory contains the Kustomize overlay and bootstrap scripts for deploying Platform Mesh to a production Kubernetes cluster.

For local development, use [`local-setup/`](../local-setup/README.md) instead.

---

## Prerequisites

The following must be installed and running before applying this overlay:

| Requirement | Notes |
|-------------|-------|
| Kubernetes 1.28+ | Any CNCF-conformant distribution |
| [FluxCD](https://fluxcd.io) 2.17.0 | See install command below |
| External domain + wildcard TLS certificate | e.g. `*.example.com` — TLS is terminated at the ingress/gateway layer |
| [kubectl oidc-login](https://github.com/int128/kubelogin) | Required on client machines for user OIDC auth (`kubectl krew install oidc-login`) |
| [kubectl kcp](https://github.com/kcp-dev/kcp/tree/main/cli/cmd/kubectl-kcp) | kcp workspace management plugin (`kubectl krew install kcp`) |
| [KRO](https://kro.run/) | Kube Resource Orchestrator |

---

## Deployment Steps

### 0. Decide which version to install

Users have 2 options - an official release, e.g. `0.5` or developer builds labelled like `0.5.1-build.94`. Those are delivered as OCM components on the `github.com/platform-mesh/helm-charts`. For example to list the latest available build:
```shell
$ ocm get cv "ghcr.io/platform-mesh//github.com/platform-mesh/platform-mesh" -o tree --latest
 NESTING  COMPONENT                               VERSION         PROVIDER                IDENTITY                                                           
 └─       github.com/platform-mesh/platform-mesh  0.5.1-build.94  The Platform Mesh Team  name=github.com/platform-mesh/platform-mesh,version=0.5.1-build.94 
```

### 1. Install FluxCD

```bash
KUBECONFIG=<path-to-kubeconfig> helm upgrade -i -n flux-system --create-namespace flux \
  oci://ghcr.io/fluxcd-community/charts/flux2 \
  --version 2.17.0 \
  --set imageAutomationController.create=false \
  --set imageReflectionController.create=false \
  --set notificationController.create=false \
  --set helmController.container.additionalArgs[0]="--concurrent=10" \
  --set sourceController.container.additionalArgs[1]="--requeue-dependency=5s"
```

> **Version note:** Use 2.17.0. Newer versions enable server-side apply with `fieldValidation=Strict`, which rejects resources from the `infra` chart that contain fields not declared in the kcp-operator CRD schema. See https://github.com/platform-mesh/helm-charts/pull/2509.

### 2. Run bootstrap.sh

Generates all required secrets with random values. Safe to run multiple times (idempotent).

```bash
NAMESPACE=platform-mesh-system bash production-setup/scripts/bootstrap.sh
```

If you have an OpenSearch instance for the search-operator, set these before running:

```bash
export OPENSEARCH_URL=https://opensearch.example.com:9200
export OPENSEARCH_USERNAME=admin
export OPENSEARCH_PASSWORD=<password>
KUBECONFIG=target.kubeconfig production-setup/scripts/bootstrap.sh
```

### 3. Set your base domain

Edit `production-setup/kustomize/overlays/platform-mesh-resource/platform-mesh.yaml`:

```yaml
spec:
  exposure:
    baseDomain: "platform.example.com"   # replace REPLACE_ME
```

### 4. Set required values in the profile

Edit `production-setup/kustomize/overlays/platform-mesh-resource/default-profile.yaml` and search for `REQUIRED`:

**Keycloak hostname** (search `REPLACE_ME`):
```yaml
keycloak:
  operator:
    hostname: "https://platform.example.com"   # your production URL, no trailing slash
```

**SMTP server** (search `REQUIRED: SMTP`):
```yaml
security-operator:
  values:
    fga:
      extraArgs:
        - --idp-smtp-server=smtp.example.com
        - --idp-smtp-port=587
        - --idp-from-address=noreply@example.com
```

> **Initial install without SMTP:** For a first install or testing, you can skip SMTP by setting `smtp.server: ""` and enabling `allowUnverifiedEmails: true` under the `security-operator` `idp:` block. This lets users log in without email verification. Change these values before going to production.

### 5. Bootstrap cluster dependencies

The PlatformMesh CRD does not exist on a fresh cluster, so applying the overlay directly fails. Install the required controllers first:

```bash
# Namespaces, KRO, OCM controller
kubectl apply -k production-setup/kustomize/namespaces
kubectl apply -k production-setup/kustomize/kro
kubectl apply -k production-setup/kustomize/ocm-k8s-toolkit

kubectl apply -k production-setup/kustomize/ocm

# PlatformMesh operator CRDs and operator itself
kubectl apply -k production-setup/kustomize/platform-mesh-operator-crds
kubectl apply -k production-setup/kustomize/rgd
kubectl apply -k production-setup/kustomize/platform-mesh-operator
```

Wait for the platform-mesh-operator to become ready before proceeding.

### 6. Apply the overlay

```bash
kubectl apply -k production-setup/kustomize/overlays/platform-mesh-resource
```

## 7. DNS Records

Once Traefik's LoadBalancer Service is assigned an external IP, create these DNS A records:

```
<base-domain>.          A  300  <LoadBalancer-IP>
*.<base-domain>.        A  300  <LoadBalancer-IP>
```

Get the IP:

```bash
kubectl get svc traefik -n default -ojsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 8. Verify

```bash
# Check the PlatformMesh CR reconciles successfully
kubectl get platformmesh -n platform-mesh-system platform-mesh

# Check all HelmReleases are ready
kubectl get helmrelease -n platform-mesh-system

# Check Keycloak is up
kubectl get keycloak -n platform-mesh-system
```

---


---

## TLS Secrets

Two TLS secrets must exist in `platform-mesh-system` before the overlay is applied. They are **not** created by `bootstrap.sh`. Obtain a certificate for the required hostnames using any CA or tooling of your choice (cert-manager, manual issuance, corporate PKI, etc.).

### Required hostnames

The certificate must cover:

```
<base-domain>
*.<base-domain>
```

### Secret: `domain-certificate`

Holds the TLS certificate and private key:

```bash
kubectl create secret generic domain-certificate \
  -n platform-mesh-system \
  --from-file=tls.crt=/path/to/tls.crt \
  --from-file=tls.key=/path/to/tls.key \
  --type=kubernetes.io/tls \
  --dry-run=client -o yaml | kubectl apply -f -
```

`tls.crt` should be the full chain (leaf + intermediates). The private key must match the leaf certificate.

### Secret: `domain-certificate-ca`

Holds the root CA certificate. Operators use this to trust outbound TLS connections:

```bash
kubectl create secret generic domain-certificate-ca \
  -n platform-mesh-system \
  --from-file=tls.crt=/path/to/ca.crt \
  --from-file=ca.crt=/path/to/ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

Use the root CA — not an intermediate — so the trust chain is complete.

---

## Secrets Created by bootstrap.sh

| Secret | Namespace | Contents |
|--------|-----------|----------|
| `keycloak-admin` | `platform-mesh-system` | `username`, `password`, `secret` (OIDC client secret) |
| `cnpg-keycloak-user` | `platform-mesh-system` | `username`, `password` |
| `keycloak-db-credentials` | `platform-mesh-system` | `username`, `password` |
| `cnpg-openfga-user` | `platform-mesh-system` | `username`, `password` |
| `openfga-postgres-credentials` | `platform-mesh-system` | `password`, `postgres-password` |
| `search-operator-opensearch` | `platform-mesh-system` | `url`, `username`, `password` (only if env vars are set) |

---

## Key Differences from local-setup

| Aspect | local-setup | production-setup |
|--------|-------------|------------------|
| TLS | Terminated at Kind node via mkcert | Terminated externally at your ingress/gateway |
| PostgreSQL | CNPG cluster managed by the infra chart | Same — CNPG cluster, secrets pre-created by bootstrap.sh |
| Credentials | Hardcoded dev values in profiles | Random secrets generated by bootstrap.sh |

---

## Organization Onboarding

Follow these steps to onboard a new organization after the platform is running.

### 1. Create a user in Keycloak

Create a new user in the Keycloak `welcome` realm for the organization's initial admin. This can be done via the Keycloak admin console or the admin API.

> **Important:** Mark the user's email as **verified** in Keycloak before they attempt to log in. kcp's OIDC authenticator validates the `email_verified` claim and rejects unverified tokens with `oidc: email not verified`.

### 2. Craft a kubeconfig with OIDC login

The user needs a kubeconfig that authenticates via OIDC using the `kubectl oidc-login` plugin. Replace `<kcp-server>`, `<keycloak-base-url>`, and `<oidc-client-id>` with values from your deployment:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <base64-encoded-ca>
    server: https://<kcp-server>:443/clusters/root:orgs
  name: base
- cluster:
    certificate-authority-data: <base64-encoded-ca>
    server: https://<kcp-server>:443/clusters/root:orgs
  name: default
- cluster:
    certificate-authority-data: <base64-encoded-ca>
    server: https://<kcp-server>:443/clusters/root:orgs
  name: workspace.kcp.io/current
- cluster:
    certificate-authority-data: <base64-encoded-ca>
    server: https://<kcp-server>:443/clusters/root:orgs
  name: workspace.kcp.io/previous
contexts:
- context:
    cluster: base
    user: platform-user
  name: base
- context:
    cluster: default
    user: platform-user
  name: default
- context:
    cluster: workspace.kcp.io/current
    user: platform-user
  name: workspace.kcp.io/current
- context:
    cluster: workspace.kcp.io/previous
    user: platform-user
  name: workspace.kcp.io/previous
current-context: workspace.kcp.io/current
kind: Config
preferences: {}
users:
- name: platform-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://<keycloak-base-url>/keycloak/realms/welcome
      - --oidc-client-id=<oidc-client-id>
      - --oidc-extra-scope=offline_access
      - --oidc-extra-scope=email
      - --oidc-extra-scope=profile
      - --oidc-use-pkce
      - --grant-type=auto
      command: kubectl
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
```

The `<base64-encoded-ca>` value is the kcp front-proxy CA, retrievable from the `domain-certificate-ca` secret in `platform-mesh-system`.

> The `kubectl oidc-login` plugin is provided by [kubelogin](https://github.com/int128/kubelogin). Install it with `kubectl krew install oidc-login`.

### 3. Grant temporary admin access to root:orgs

Switch to a kubeconfig that targets the `root:orgs` KCP workspace and grant the new user cluster-admin access:

```bash
kubectl create clusterrolebinding <username>-admin \
  --clusterrole=cluster-admin \
  --user="<user-email>"
```

### 4. Apply the Account CR

Using the user's kubeconfig (targeting `root:orgs`), create the organization Account:

```yaml
apiVersion: core.platform-mesh.io/v1alpha1
kind: Account
metadata:
  name: <org-name>
spec:
  type: org
  displayName: <Display Name>
  creator: <user-email>
```

```bash
kubectl apply -f account.yaml
```

### 5. Verify the Account is ready

```bash
kubectl get account <org-name>
```

Wait until the `Ready` condition is `True`.

### 6. Cleanup

Remove the temporary admin binding and the Keycloak user once the organization has been successfully onboarded:

```bash
kubectl delete clusterrolebinding <username>-admin
```

Delete the temporary user from the Keycloak `welcome` realm via the admin console.
