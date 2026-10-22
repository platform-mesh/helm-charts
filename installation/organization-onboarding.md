# Organization onboarding

Two paths are available for onboarding a new organization:

- **Portal** (recommended when the Platform Mesh portal is deployed): a
  browser-based flow that requires no `kubectl` access for the end user.
- **kubectl** (always available): a command-line flow for environments without
  a portal, or for operators who prefer direct API access.

---

## Portal-based onboarding

### 1. Create a Keycloak user

Create a user in the Keycloak `welcome` realm for the organization's initial
administrator. Use the Keycloak administration console or API and mark the
user's email address as verified before the first login.

> kcp's OIDC authenticator validates the `email_verified` claim and rejects
> unverified tokens with `oidc: email not verified`.

If self-registration is enabled (`idp.registrationAllowed: true` in the
security-operator values), users can register directly from the login page and
this step is not required.

### 2. Open the portal

Navigate to the portal URL and log in with the user's credentials:

- **Production**: `https://<base-domain>/`
- **Kind**: `https://<base-domain>:8443/`

For example, if `base_domain=portal.orgdomain`, the Kind URL is
`https://portal.orgdomain:8443/`.

After login the portal shows the **Organization management** panel. If it
instead shows a "Welcome! Let's get started." screen, the user is already
inside an organization — navigate back to the root portal URL to reach the
Organization management panel.

### 3. Create the organization

Enter the organization name in the **Organization name** field and click
**Onboard**. Platform Mesh creates an `Account` resource of type `org` and a
dedicated Keycloak realm for the organization in the background.

Wait for the **Switch** button to become active — this indicates the
organization workspace is ready.

### 4. Switch to the organization

Click **Switch**. The portal redirects to the organization-scoped portal at
`https://<org-name>.<base-domain>/` (Kind: `https://<org-name>.<base-domain>:8443/home/overview`).

The browser is redirected through the new organization's Keycloak realm. For a
first-time login in that realm you will go through several screens in sequence:

1. **Sign in** — enter your email and password.
2. **Update password** — set a new password if the account was pre-created by
   an administrator.
3. **Update profile** — enter first and last name if not yet on the account.
4. **Back to Application** — click the link to return to the portal after
   completing the profile setup.
5. You may be asked to sign in once more after these steps complete.

Work through each screen as it appears. Once all Keycloak setup screens are
done the portal loads the organization home page.

### 5. Create accounts

Navigate to **Accounts** in the left-hand navigation of the organization portal
(`/home/accounts`) and click **Create**. Fill in the account name and set the
**Type** field to `account` — the **Save** button remains disabled until a type
is selected. Click **Save**.

Repeat for each account that belongs to the organization.

### 6. Download the account kubeconfig

Open an account's dashboard (`/home/accounts/<account-name>/dashboard`) and
click **Download kubeconfig**. The portal generates an OIDC kubeconfig scoped
to that account's workspace. Users can use this kubeconfig with any standard
`kubectl` client.

### 7. Invite additional members (optional)

> This step requires a working SMTP relay (`idp.smtp` in the security-operator
> values). Without one, the invitation is created but the invited user never
> receives the email and cannot complete their account setup.

Navigate to **Members** in the left-hand navigation and click **Add**. Search
for the user's email address, select the **Invite** entry from the dropdown,
and click **Add**. The invited user receives an email with a link to set up
their account in the organization's Keycloak realm.

---

## kubectl-based onboarding

Follow these steps after Platform Mesh is ready to onboard a new organization.

### 1. Create a Keycloak user

Create a user in the Keycloak `welcome` realm for the organization's initial
administrator. Use the Keycloak administration console or API and mark the
user's email address as verified before the first login. kcp's OIDC
authenticator validates the `email_verified` claim and rejects unverified tokens
with `oidc: email not verified`.

### 2. Create an OIDC kubeconfig

The user needs a kubeconfig that authenticates with the `kubectl oidc-login`
plugin. In the example below:

- `<base-domain>` is the Platform Mesh base domain.
- `<external-port>` is `443` for the production example or `8443` for Kind.
- `<oidc-client-id>` is the Keycloak OIDC client ID; the default installation
  uses `welcome`.
- `<base64-encoded-domain-ca>` is the certificate authority that signs the
  external domain certificate.

Retrieve the already base64-encoded CA data from the installation Secret:

```shell
kubectl --namespace platform-mesh-system \
  get secret domain-certificate-ca \
  --output jsonpath='{.data.tls\.crt}'
```

Install the
[`kubectl oidc-login`](https://github.com/int128/kubelogin) plugin with
`kubectl krew install oidc-login`, then create the user's kubeconfig:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: base
    cluster:
      certificate-authority-data: <base64-root-ca>
      server: https://kcp.api.<base-domain>:<external-port>/clusters/root:orgs
  - name: default
    cluster:
      certificate-authority-data: <base64-root-ca>
      server: https://kcp.api.<base-domain>:<external-port>/clusters/root:orgs
  - name: workspace.kcp.io/current
    cluster:
      certificate-authority-data: <base64-root-ca>
      server: https://kcp.api.<base-domain>:<external-port>/clusters/root:orgs
  - name: workspace.kcp.io/previous
    cluster:
      certificate-authority-data: <base64-root-ca>
      server: https://kcp.api.<base-domain>:<external-port>/clusters/root:orgs
contexts:
  - name: base
    context:
      cluster: base
      user: platform-user
  - name: default
    context:
      cluster: default
      user: platform-user
  - name: workspace.kcp.io/current
    context:
      cluster: workspace.kcp.io/current
      user: platform-user
  - name: workspace.kcp.io/previous
    context:
      cluster: workspace.kcp.io/previous
      user: platform-user
current-context: workspace.kcp.io/current
preferences: {}
users:
  - name: platform-user
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubectl
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://<base-domain>:<external-port>/keycloak/realms/welcome
          - --oidc-client-id=<oidc-client-id>
          - --oidc-extra-scope=offline_access
          - --oidc-extra-scope=email
          - --oidc-extra-scope=profile
          - --oidc-use-pkce
          - --grant-type=auto
        env: null
        interactiveMode: IfAvailable
        provideClusterInfo: false
```

### 3. Grant temporary access to `root:orgs`

Use an administrative kubeconfig (fetch using
[tests/create-kcp-admin-kubeconfig.sh](../tests/create-kcp-admin-kubeconfig.sh))
that targets the `root:orgs` kcp workspace to grant the new user temporary
`cluster-admin` access:

```shell
kubectl create clusterrolebinding <username>-admin \
  --clusterrole=cluster-admin \
  --user="<user-email>"
```

### 4. Create the organization account

Using the new user's OIDC kubeconfig, apply an `Account` resource:

```yaml
apiVersion: core.platform-mesh.io/v1alpha1
kind: Account
metadata:
  name: <organization-name>
spec:
  type: org
  displayName: <Organization Display Name>
  creator: <user-email>
```

```shell
kubectl apply --filename account.yaml
```

### 5. Verify the account

```shell
kubectl get account <organization-name>
```

Wait until the account's `Ready` condition is `True`.

### 6. Remove temporary access

Using the administrative `root:orgs` kubeconfig, remove the temporary binding:

```shell
kubectl delete clusterrolebinding <username>-admin
```
