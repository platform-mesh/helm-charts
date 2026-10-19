# Organization onboarding

Follow these steps after Platform Mesh is ready to onboard a new organization.

## 1. Create a Keycloak user

Create a user in the Keycloak `welcome` realm for the organization's initial
administrator. Use the Keycloak administration console or API and mark the
user's email address as verified before the first login. kcp's OIDC
authenticator validates the `email_verified` claim and rejects unverified tokens
with `oidc: email not verified`.

## 2. Create an OIDC kubeconfig

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

## 3. Grant temporary access to `root:orgs`

Use an administrative kubeconfig (fetch using
[tests/create-kcp-admin-kubeconfig.sh](../tests/create-kcp-admin-kubeconfig.sh))
that targets the `root:orgs` kcp workspace to grant the new user temporary
`cluster-admin` access:

```shell
kubectl create clusterrolebinding <username>-admin \
  --clusterrole=cluster-admin \
  --user="<user-email>"
```

## 4. Create the organization account

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

## 5. Verify the account

```shell
kubectl get account <organization-name>
```

Wait until the account's `Ready` condition is `True`.

## 6. Remove temporary access

Using the administrative `root:orgs` kubeconfig, remove the temporary binding:

```shell
kubectl delete clusterrolebinding <username>-admin
```
