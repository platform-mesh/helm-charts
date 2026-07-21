# Dex upstream identity provider (local-setup)

Local-setup deploys [Dex](https://dexidp.io/) as a second OIDC issuer alongside
Keycloak. Use it to develop and test upstream identity provider federation in
the portal and security-operator.

## Endpoints

| Purpose | URL |
|---------|-----|
| Issuer | `https://portal.localhost:8443/dex` |
| OIDC discovery | `https://portal.localhost:8443/dex/.well-known/openid-configuration` |
| Login UI | `https://portal.localhost:8443/dex/auth` |

## Test user

Dex is configured with a local password connector and one documented test user:

| Field | Value |
|-------|-------|
| Email | `dex@portal.localhost` |
| Username | `dex` |
| Password | `dex` |

## Automated federation (default org)

When the local-setup profile is used, the security-operator initializer seeds
Dex as an upstream identity provider for the `default` org automatically when
that org is created (for example after registering via the portal).

The seed configuration is mounted from a ConfigMap into the initializer
(`--idp-seed-config-file=/config/idp-seed.yaml`). For the default profile it
registers:

| Field | Value |
|-------|-------|
| Alias | `dex` |
| Discovery endpoint | `https://portal.localhost:8443/dex/.well-known/openid-configuration` |
| Client ID | `keycloak-broker` |
| Client secret | `local-dev-broker-secret` |
| Client authentication | Client sent in the request body (`client_secret_post`) |

The initializer creates the broker client secret in `root:orgs` and adds
`spec.upstreamIdentityProviders` to the org's
`IdentityProviderConfiguration`. The security-operator reconciler then
configures Keycloak and reports readiness in
`status.managedUpstreamIdentityProviders[dex].ready`.

The default local-setup profile pre-configures the Dex static client redirect
URI for the `default` org realm only:

`https://portal.localhost:8443/keycloak/realms/default/broker/dex/endpoint`

After registering the `default` org in the portal, you should be able to log in
via Dex using `dex@portal.localhost` / `dex`.

For **email-only first step** login with automatic Dex redirect for matching
`@portal.localhost` addresses (no Dex button), see
[upstream-identity-provider-identity-first-login.md](./upstream-identity-provider-identity-first-login.md).
The default profile seeds `emailDomainRouting` on the Dex upstream; the
security-operator reconciles Keycloak Organizations during `task local-setup`.

Verify automation with:

```bash
./local-setup/scripts/check-backend-resources.sh
```

To also verify a non-default org's Dex callback is registered:

```bash
DEX_ORG=<org> ./local-setup/scripts/check-backend-resources.sh
```

## Manual Keycloak UI setup (fallback)

If seeding is disabled or you need another org realm, add Dex manually in the
Keycloak admin console:

1. Open the Keycloak admin console for the target org realm, e.g. for the `default` realm (of an organization `default`): `https://portal.localhost:8443/keycloak/admin/master/console/#/default`
2. Go to **Identity providers** → **Add provider** → **OpenID Connect v1.0**
3. Enter the following fields:

| Keycloak field | Value |
|----------------|-------|
| Alias | `dex` |
| Discovery endpoint | `https://portal.localhost:8443/dex/.well-known/openid-configuration` |
| Client ID | `keycloak-broker` |
| Client secret | `local-dev-broker-secret` |
| Client authentication | Client sent in the request body |

4. Save the provider.
5. After saving, Keycloak shows the broker redirect URI, e.g.
   `https://portal.localhost:8443/keycloak/realms/default/broker/dex/endpoint`.
   This URI must be listed in Dex `staticClients.redirectURIs`.

For org realms other than `default`, register the broker redirect URI in Dex
before logging in via Dex. Dex does not support wildcard redirect URIs, so each
org realm needs its own entry:

`https://portal.localhost:8443/keycloak/realms/<org>/broker/dex/endpoint`

After creating an org in the portal, run:

```bash
task local-setup:dex-callback ORG=<org>
```

This appends the org's broker callback to the Dex `keycloak-broker` static
client in the cluster and restarts Dex. The Keycloak side (upstream IdP seeding
and broker configuration) is already handled automatically by the initializer
and security-operator.

When `initializer.idpSeed.seedUpstreamIdentityProviders.realms` is omitted or
empty, the initializer does **not** seed any org. List org names explicitly to
enable seeding (for example `realms: [default]` for the default org only).

You should now be able to log into the org with the test user mentioned above.
