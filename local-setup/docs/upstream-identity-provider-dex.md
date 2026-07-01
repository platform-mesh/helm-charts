# Dex upstream identity provider (local-setup)

Local-setup deploys [Dex](https://dexidp.io/) as a second OIDC issuer alongside
Keycloak. Use it to develop and test upstream identity provider federation in
the portal and security-operator.

## Endpoints

| Purpose | URL |
|---------|-----|
| Issuer | `https://portal.localhost:8443/dex` |
| OIDC discovery | `https://portal.localhost:8443/dex/.well-known/openid-configuration` |
| Login UI | `https://portal.localhost:8443/dex/auth` |```

## Test user

Dex is configured with a local password connector and one documented test user:

| Field | Value |
|-------|-------|
| Email | `dex@portal.localhost` |
| Username | `dex` |
| Password | `dex` |

## Keycloak identity broker setup

Use these values when adding Dex as an upstream identity provider in a
Keycloak organization realm manually via UI:

1. Open the Keycloak admin console for the target org realm, e.g. for the `default` realm(of an organization `default`): `https://portal.localhost:8443/keycloak/admin/master/console/#/default`
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

The default local-setup profile pre-configures the redirect URI for the
`default` org realm. For other org realms, add the broker redirect URI to the
`dex.staticClient.redirectURIs` list in the local-setup profile.

You should now be able to log into the `default` org with the test user mentioned above.
