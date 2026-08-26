# Platform Mesh — Production Setup

This directory contains the Kustomize overlay and bootstrap scripts for deploying Platform Mesh to a production Kubernetes cluster.

For local development, use [`local-setup/`](../local-setup/README.md) instead.

---

## Prerequisites

The following must be installed and running in your cluster before applying this overlay:

| Requirement | Notes |
|-------------|-------|
| Kubernetes 1.28+ | Any CNCF-conformant distribution |
| [cert-manager](https://cert-manager.io) | For certificate issuance |
| [CNPG operator](https://cloudnative-pg.io) | CloudNative PostgreSQL — manages the shared Postgres cluster |
| [Keycloak operator](https://www.keycloak.org/operator/installation) | Manages the Keycloak instance |
| [FluxCD](https://fluxcd.io) or [ArgoCD](https://argo-cd.readthedocs.io) | GitOps controller for deploying components via OCM |
| [Gateway API CRDs](https://gateway-api.sigs.k8s.io/guides/) | `gateway.networking.k8s.io` v1 or later |
| External domain + wildcard TLS certificate | e.g. `*.example.com` — TLS is terminated at the ingress/gateway layer |
| SMTP server | Required for email invitations sent by the security-operator |

---

## Deployment Steps

### 1. Run bootstrap.sh

Generates all required secrets with random values. Safe to run multiple times (idempotent).

```bash
NAMESPACE=platform-mesh-system bash production-setup/scripts/bootstrap.sh
```

If you have an OpenSearch instance for the search-operator, set these before running:

```bash
export OPENSEARCH_URL=https://opensearch.example.com:9200
export OPENSEARCH_USERNAME=admin
export OPENSEARCH_PASSWORD=<password>
bash production-setup/scripts/bootstrap.sh
```

### 2. Set your base domain

Edit `production-setup/kustomize/overlays/platform-mesh-resource/platform-mesh.yaml`:

```yaml
spec:
  exposure:
    baseDomain: "platform.example.com"   # replace REPLACE_ME
```

### 3. Set required values in the profile

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

### 4. Apply the overlay

```bash
kubectl kustomize production-setup/kustomize/overlays/platform-mesh-resource | kubectl apply -f -
```

### 5. Verify

```bash
# Check the PlatformMesh CR reconciles successfully
kubectl get platformmesh -n platform-mesh-system platform-mesh

# Check all HelmReleases are ready
kubectl get helmrelease -n platform-mesh-system

# Check Keycloak is up
kubectl get keycloak -n platform-mesh-system
```

---

## TLS Secrets (must be created manually before applying)

Two TLS secrets must exist in `platform-mesh-system` before the overlay is applied. They are **not** created by `bootstrap.sh` — they depend on your external certificate authority.

### `domain-certificate`

Holds the wildcard TLS certificate for your base domain. Referenced by the Gateway API listeners for HTTPS termination.

```bash
kubectl create secret generic domain-certificate \
  -n platform-mesh-system \
  --from-file=tls.crt=/path/to/wildcard.crt \
  --from-file=tls.key=/path/to/wildcard.key \
  --from-file=ca.crt=/path/to/ca.crt \
  --type=kubernetes.io/tls \
  --dry-run=client -o yaml | kubectl apply -f -
```

The certificate must cover at minimum `*.platform.example.com` (substitute your actual base domain).

### `domain-certificate-ca`

Holds only the CA certificate. Used by operators (`security-operator`, `iam-service`, `search-operator`) to trust outbound HTTPS connections to services signed by your CA (e.g. Keycloak, KCP front-proxy).

```bash
kubectl create secret generic domain-certificate-ca \
  -n platform-mesh-system \
  --from-file=tls.crt=/path/to/ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

> **Note:** These secrets are not automatically rotated. If you use cert-manager, you can manage them as `Certificate` resources pointing at your cluster issuer. If you manage certificates externally (e.g. Let's Encrypt via DNS-01), set up a rotation mechanism (e.g. `external-secrets`, a renewal cron job) to keep these secrets current.

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
| Identity provider | Dex (bundled, local-only) | External IdP required (configure via Keycloak broker) |
| SMTP | Mailpit (local mail catcher) | Real SMTP server required |
| Credentials | Hardcoded dev values in profiles | Random secrets generated by bootstrap.sh |
| Email verification | Disabled (feature toggle) | Enabled (default, no toggle set) |
| KCP port | 8443 | 443 |

---

## Organization Onboarding

Follow these steps to onboard a new organization after the platform is running.

### 1. Create a user in Keycloak

Create a new user in the Keycloak `welcome` realm for the organization's initial admin. This can be done via the Keycloak admin console or the admin API.

### 2. Craft a kubeconfig with OIDC login

The user needs a kubeconfig that authenticates via OIDC using the `kubectl oidc-login` plugin. Replace `<kcp-server>`, `<keycloak-base-url>`, and `<oidc-client-id>` with values from your deployment:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <base64-encoded-ca>
    server: https://<kcp-server>:443/clusters/root:orgs
  name: workspace.kcp.io/current
contexts:
- context:
    cluster: workspace.kcp.io/current
    user: platform-user
  name: default
current-context: default
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
