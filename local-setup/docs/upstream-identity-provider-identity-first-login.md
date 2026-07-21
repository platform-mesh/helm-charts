# Identity-first login with email-domain redirect (local-setup)

This guide explains **email-only first step** login on a Keycloak org realm, with
**automatic redirect to an upstream IdP** (Dex in local-setup) when the email
domain matches — without showing a Dex button on the login page.

In local-setup this is **declarative**: the Dex upstream seed includes
`emailDomainRouting`, and the security-operator reconciles Keycloak Organizations
(realm flag, organization, broker link) from the `IdentityProviderConfiguration`
CR.

## How it works

```text
User enters email on Keycloak login page
  |
  +-- domain matches configured org domain AND user has no local Keycloak password?
  |     -> redirect to upstream IdP (Dex)
  |
  +-- other domain OR user already has local Keycloak credentials?
        -> Keycloak username/password form
```

Keycloak 26 ships the required browser flow (**Organization Identity-First
Login**). The security-operator enables it by:

1. Setting `organizationsEnabled` on the org realm when any upstream has
   `emailDomainRouting` with `autoRedirect: true`
2. Creating a Keycloak **Organization** for the configured email domains
3. Linking the upstream IdP broker (e.g. `dex`) with redirect and hide-on-login
   settings

## What local-setup configures automatically

| Step | Mechanism |
|------|-----------|
| Dex upstream broker seed | `initializer.idpSeed` in `default-profile.yaml` |
| Identity-first fields on Dex | `emailDomainRouting` (`domains`, `autoRedirect`, `hideUntilDomainMatch`), `hideOnLoginPage` |
| Keycloak Organizations + broker link | security-operator reconcile |
| Dex callback for `default` org | Pre-seeded in Dex `staticClients.redirectURIs` |
| Post-install verification | `check-backend-resources.sh` waits for `dex.ready` and `organizationId` |

Default seed (abbreviated):

```yaml
idpSeed:
  enabled: true
  seedUpstreamIdentityProviders:
    realms:
      - default
    providers:
      - alias: dex
        hideOnLoginPage: true
        emailDomainRouting:
          domains:
            - portal.localhost
          autoRedirect: true
          hideUntilDomainMatch: true
        # ... oidc discoveryUrl, clientId, etc.
```

When `seedUpstreamIdentityProviders.realms` is omitted or empty, the initializer
does **not** apply this upstream to any org. List org names explicitly (for
example `realms: [default]`) to enable seeding for those realms.

## Prerequisites (per org)

| Step | What |
|------|------|
| 1 | Org registered in portal (Keycloak realm `<org>` exists) |
| 2 | Upstream IdP broker reconciled (`status.managedUpstreamIdentityProviders.dex.ready=true`) |
| 3 | Identity-first linked (`status.managedUpstreamIdentityProviders.dex.organizationId` set) |
| 4 | Dex broker redirect URI registered for the org (Dex static client) |

### Verify operator status

```bash
kubectl --kubeconfig helm-charts/.secret/kcp/admin.kubeconfig \
  --server "https://kcp.api.portal.localhost:8443/clusters/root:orgs" \
  get identityproviderconfigurations.core.platform-mesh.io <org> \
  -o jsonpath='{.status.managedUpstreamIdentityProviders.dex}{"\n"}'
```

Expected fields when ready:

- `ready: true`
- `organizationId: <uuid>`
- `linkedEmailDomains: ["portal.localhost"]`

Or run the full backend check:

```bash
task test:backend-resources
# or: ./local-setup/scripts/check-backend-resources.sh
```

### Dex callback per org

The `default` org callback is pre-seeded. For other orgs, after portal
registration:

```bash
task local-setup:dex-callback ORG=<org>
```

## Test login

Use a **new** `@portal.localhost` address (not an existing Keycloak user with a
local password):

```text
newuser@portal.localhost
```

Dex credentials after redirect: `dex@portal.localhost` / `dex`

## Per-org checklist

| Org | Dex callback | Identity-first login |
|-----|--------------|----------------------|
| `default` | Pre-seeded in Dex config | Automatic via operator + seed |
| `<other>` | `task local-setup:dex-callback ORG=<other>` | Add org to `realms` in seed config, or configure upstream manually |

## Manual troubleshooting

Use these when the operator is unavailable, you are on an older image without
identity-first reconcile, or you need to inspect Keycloak directly.

### Keycloak admin UI

1. Open `https://portal.localhost:8443/keycloak/admin/master/console/#/<org>`
2. **Realm settings** → enable **Organizations**
3. **Organizations** → create org with domain `portal.localhost`
4. **Organizations** → your org → **Identity providers** → link `dex` with:
   - Domain: `portal.localhost` → `emailDomainRouting.domains`
   - Hide on login page: **On** → `hideOnLoginPage`
   - Hide on login page when organization not resolved: **On** → `emailDomainRouting.hideUntilDomainMatch`
   - Redirect when email domain matches: **On** → `emailDomainRouting.autoRedirect`

See `IdentityProviderConfiguration` (`spec.upstreamIdentityProviders`) and the [design on backlog#286](https://github.com/platform-mesh/backlog/issues/286#issuecomment-4450331334).

### Admin REST API (snippet)

```bash
TOKEN=$(curl -sk -X POST "https://portal.localhost:8443/keycloak/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" -d "client_id=admin-cli" \
  -d "username=keycloak-admin" -d "password=admin" | jq -r .access_token)

BASE="https://portal.localhost:8443/keycloak/admin/realms/<org>"

curl -sk -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE" -d '{"organizationsEnabled": true}'
```

Broker `config` keys set by the operator:

| Key | Value |
|-----|-------|
| `kc.org.domain` | `<domain>` |
| `kc.org.broker.redirect.mode.email-matches` | `true` |
| `kc.org.broker.login.hide-when-org-unknown` | `true` |

## Caveat: existing local Keycloak users

If an email already exists in the org realm **with a local password**, Keycloak
shows the password form instead of redirecting to the upstream IdP — even when
the domain matches.

For Dex SSO testing with `dex@portal.localhost`:

- Use a new `@portal.localhost` address, **or**
- Delete the local Keycloak user **Users** → `dex@portal.localhost` in the org
  realm, then retry.

## Related docs

- [Dex upstream IdP](./upstream-identity-provider-dex.md) — broker seeding and Dex redirect URIs
- [backlog#286](https://github.com/platform-mesh/backlog/issues/286) — upstream IdP epic and [Portal design comment](https://github.com/platform-mesh/backlog/issues/286#issuecomment-4450331334)

## KCP API schema for `IdentityProviderConfiguration`

Local-setup creates `identityproviderconfigurations.core.platform-mesh.io` objects in
KCP (`root:orgs`). Those CRs require a matching **KCP APIResourceSchema** on
`system.platform-mesh.io`.

The `security-operator-crds` Helm chart ships KCP APIResourceSchemas for
`authorizationmodels`, `identityproviderconfigurations`, and `stores`. The schema
is generated in `platform-mesh/operators/security-operator/config/resources/`
(`task generate`); keep this chart in sync when the CRD changes.

**What this means for local-setup:**

- Fresh installs via the `security-operator` Helm chart apply the IdP schema
  automatically — no manual `apply-idp-kcp-schema.sh` step required.
- If you are on an older chart release without the schema, or upgrading an
  existing cluster, use `local-setup/scripts/apply-idp-kcp-schema.sh` (set
  `IDP_SCHEMA_FILE` to the schema YAML from the operator release or
  `platform-mesh/apis`) until you deploy an updated `security-operator-crds`
  version.

This script is **not** wired into the default local-setup flow; it remains for
optional MCP/tooling and cluster upgrades.
