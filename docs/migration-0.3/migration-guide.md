# Migration Guide: 0.2.0 → 0.3.0

> **About the field notes in this document.** The blockquoted **🔧 Field note** callouts
> below were added from applying this guide on a real, multi-org, GitOps-managed cluster
> (Flux + OCM-driven), rather than the local Kind setup the procedure is written for. They
> record where the steps translated directly, where a production-style landscape needed extra
> work, and what the procedure silently omits. The original instructions are unchanged.
> _Contributed from applying this guide on a production-style GitOps cluster._

## Strategy

This is a **hybrid migration**. KCP state (etcd) is wiped and rebuilt from scratch because in-place schema upgrades are unreliable. Keycloak and OpenFGA databases are preserved in place — their data is migrated without a full delete/restore cycle. Only the OpenFGA tuples need ID fixups to match the new KCP cluster IDs.

| Component | Migration approach |
|---|---|
| KCP | Wipe etcd, fresh install, recreate workspaces, restore user resources |
| Keycloak | In-place — restore PostgreSQL secret, restart |
| OpenFGA | In-place — migrate tuples with updated cluster IDs |

> **🔧 Field note — the hybrid model holds, but "restore user resources" is the whole job**
> Wipe+rebuild KCP, preserve Keycloak+OpenFGA, re-ID the tuples — that all worked as
> described. What the table understates is how much "recreate workspaces, restore user
> resources" is actually carrying. On a real cluster, most *functional* state lives **outside**
> the two preserved databases: sub-accounts, the provider workspace tree, per-account authz
> tuples, per-provider certificates, and portal config — plus the Keycloak SSO
> federated-identity links, which *do* sit in the preserved DB but get dropped by the realm
> rebuild in §4. The rebuild comes up **structurally correct but functionally empty**, and each
> of those layers has to be reconstructed separately. Plan the migration around the restore, not
> the teardown — the teardown/rebuild was a handful of steps; the restore took roughly a
> dozen distinct repairs that this guide doesn't list.

---

## 1. Version matrix

| Component | 0.2.0 | 0.3.0 | Notes |
|---|---|---|---|
| OCM component | `0.2.0` | `0.3.0-build.1249` | drives all sub-component versions |
| OCM install method | Kustomization + GitRepository | HelmRelease (`ocm-k8s-toolkit`) | breaking change |
| platform-mesh-operator | 0.18.x | 0.19.x | |
| security-operator | 0.23.x | 0.29.x | new FGA `bind`/`bind_inherited` types |
| account-operator | — | 0.1.x | new; manages account lifecycle and FGA tuples |
| OpenFGA | 0.2.51 | 0.2.54 | |
| Keycloak | 25.x | 25.3.0 | |
| KCP | v0.29/v0.30 | 097afc12c | custom image; new `system.platform-mesh.io` APIExport |
| portal | 0.10.x | 0.10.145 | CRD gateway URL path changed |
| marketplace-ui | disabled | enabled | |
| init-agent | — | 0.2.0 | new component |

> **🔧 Field note — these are the local example versions; an OCM-driven install differs**
> This table is the `feat/migration-0.3` local example. If you install via an OCM component /
> umbrella chart, your **running image tags come from that component's BoM, not this table** —
> and the two axes drift: a chart/component version (e.g. `account-operator 0.x`) is **not**
> the image `appVersion` it deploys. Keep them straight when debugging.
> A delivery failure mode worth flagging: when OCM can't extract an image or chart resource,
> the HelmRelease's `values.image.tag` resolves **empty** and the Deployment silently falls
> back to a **stale image** (the previously-deployed tag). The visible result is a 0.3 frontend
> running against 0.2-era operators (version skew). The tell is **not** the workload — it looks
> healthy — it's the **OCM `Resource` condition** reporting `Ready=False` / `GetOCMResourceFailed`
> (`resource name=image not found in component …`). Check the OCM `Resource` conditions **and**
> the actual running image tags, not just HelmRelease status.

---

## 2. Pre-migration (on 0.2 cluster)

### 2.1 Create test data

Resources not covered by `task test:portal-e2e`:

- Account `testaccount` under `default` org
- HttpBin `test1` in `:root:orgs:default:testaccount` (namespace `default`)

> **🔧 Field note**
> Fine as a synthetic fixture. On a populated cluster your real "test data" is the live tenant
> data you're about to wipe — so the load-bearing pre-step is a complete, **restore-validated,
> off-cluster** backup (next section), not synthetic accounts.

### 2.2 Backup

```shell
local-setup/scripts/keycloak_backup.sh
local-setup/scripts/keycloak_export_realms.sh
local-setup/scripts/fga_backup.sh
local-setup/scripts/etcd_backup.sh
docs/migration-0.3/export-kcp-resources.sh local-setup/backup/kcp/0.2-userdata
docs/migration-0.3/export-kcp-resources.sh local-setup/backup/kcp-exports/pre-migration
```

> **🔧 Field note — the scripts assume a local KCP; harden the backup for a real one**
> `export-kcp-resources.sh` defaults to `KCP_SERVER=https://localhost:8443` and
> `.secret/kcp/admin.kubeconfig`. On a real cluster KCP sits behind the front-proxy — set
> `KUBECONFIG_KCP` / `KCP_SERVER` to a **super-admin client cert through the front-proxy**, or
> run the export from an in-cluster admin pod. The script discovers workspaces **recursively
> from `root`**, so the cert must be able to list *every* workspace. A narrowly-scoped (e.g.
> `root`-only) cert may lack list rights in sub-workspaces, and because the script swallows
> per-workspace list errors (`2>/dev/null`), it will **silently miss those branches** — use the
> super-admin cert.
> Two things that proved essential before crossing the point of no return: **(1)** restore-VALIDATE
> the etcd snapshot and DB dumps beforehand (we replayed the snapshot and confirmed the live
> key count), and **(2)** copy the entire kit **off the cluster and off the machine** — once
> the etcd PVC is deleted there is no second chance.

---

## 3. Install 0.3

### 3.1 Tear down 0.2

```shell
kind delete cluster --name platform-mesh
```

If preserving the Kind cluster:

```shell
kubectl -n platform-mesh-system delete PlatformMesh platform-mesh
kubectl delete components platform-mesh
kubectl delete repositories platform-mesh
kubectl delete PlatformMeshOperator platform-mesh-operator
kubectl delete ResourceGraphDefinition platform-mesh-operator
kubectl delete Resource --all
kubectl delete OCIRepository --all
kubectl delete Etcd etcd-kcp -n platform-mesh-system
kubectl delete HelmRelease --all
kubectl delete secret --all -n platform-mesh-system
kubectl delete kustomizations ocm-k8s-toolkit
kubectl delete persistentvolumeclaims etcd-kcp-etcd-kcp-0 -n platform-mesh-system
```

> **🔧 Field note — freeze GitOps first, and expect a wider cascade**
> This delete list assumes nothing is reconciling the objects back. On a GitOps cluster you
> must **suspend the Flux reconcilers / Kustomizations that own these resources first**, or
> Flux re-creates what you delete mid-teardown.
> The **owner-reference cascade is broader than this list**: deleting the operator / RGD /
> Component cascaded into cert-manager, etcd-druid and the `infra` release too — and it also
> removed the **Keycloak / OpenFGA HelmReleases and the Keycloak PostgreSQL secret** (that's why
> §4 re-applies that secret). **Only the PVCs survive.** Treat the "leave in place" items as
> aspirational and watch what the cascade actually removes; clearing finalizers in bulk
> accelerates it, so do it narrowly.
> The invariant that matters **during the cascade**: the **Keycloak and OpenFGA PVCs must stay
> `Bound`** — their databases are preserved in place and cannot be rebuilt. (The **etcd** PVC is
> the opposite: it is *deliberately* deleted as the final teardown step — its data is wiped and
> rebuilt by design, per the Strategy section. Don't try to preserve it.) Verify the
> Keycloak/OpenFGA PVCs before and after.

### 3.2 Deploy 0.3

```shell
git checkout feat/migration-0.3
task local-setup:example-data:iterate
```

Wait for readiness:

```shell
kubectl get helmrelease -A
kubectl get platformmesh -n platform-mesh-system
```

> **🔧 Field note — the `task` target is local-only; the operator/OCM path has sharp edges**
> A real cluster installs via the operator/OCM, not `task local-setup:...`. That path surfaced
> a cluster of issues this step doesn't mention:
> - **The toolkit gets installed with `crd.enable: false` / `crds: Skip`** (a value the
>   deploying chart sets), so **no** CRDs are applied — including the `Deployer` CRD the
>   controller needs (`no matches for kind "Deployer"`), plus the `delivery.ocm.software` and
>   `PlatformMesh` CRDs (`resource mapping not found`). The HelmRelease assumes the CRDs are
>   staged out-of-band, but nothing in the chart does it. Either add a CRD install step, or
>   **do not delete those CRDs during teardown**.
> - **`ocm-system` namespace is not auto-created** by the toolkit HelmRelease →
>   `namespaces "ocm-system" not found`.
> - **A pinned PostgreSQL image tag the registry never published** — the components chart
>   templated a `postgresql.image.tag` for a minor version absent from the mirror (the highest
>   published tag was an earlier minor) → `ErrImagePull: NotFound`.
> - **etcd-druid chart templating bug** (`deployment.yaml` ~line 23, "mapping values are not
>   allowed in this context"). A clean install with no surviving druid pod would wedge here.
> - **Front-proxy port mismatch** — the operator addressed the front-proxy on `:6443` but the
>   rebuilt service served `:443`, so **no workspaces were created** until both ports were
>   exposed.
> - If you author OCM resources for 0.3, also watch for CRs that reference fields/values **no
>   released OCM toolkit accepts** (an invalid `downgradePolicy` value; a `spec.interval` on
>   `Resource`), and a `referencePath` that wasn't updated for the 0.3 **two-tier**
>   (component → sub-component) OCM refactor — the chart resource can live one hop deeper than
>   the 0.2 path assumes.
>
> Operational: Flux's **helm-controller can hold a stale dependency cache** — a dependent HR
> keeps reporting a dependency "not ready" after it is actually Ready. `forceAt` doesn't clear
> it; restart the helm-controller.

---

## 4. Restore Keycloak

```shell
kubectl apply -f local-setup/backup/keycloak/postgres/keycloak-postgresql-keycloak.yaml
local-setup/scripts/keycloak_restore.sh
kubectl rollout restart statefulset/keycloak -n platform-mesh-system
kubectl rollout status statefulset/keycloak -n platform-mesh-system
```

Delete stale Keycloak clients (named after old GUIDs) from the `default` realm in the admin console.

> **🔧 Field note — preserved realms can crash the operator; the cleanup is more than cosmetic**
> Restoring the preserved realms tripped a Keycloak **duplicate-realm crash** on the operator's
> realm-create (`ModelDuplicateException → ArrayIndexOutOfBoundsException → HTTP 500`). It is
> **version-sensitive** — we hit it on a 26.x Keycloak, newer than the matrix's 25.3.0.
> Workaround: delete the preserved **user** realms via `kcadm` and let the operator recreate
> them fresh; leave shared/infra realms alone. Two caveats this step omits:
> - Deleting a realm drops its **SSO federated-identity links**. Re-login then fails with
>   "account already exists" and **can't self-complete** without SMTP or an auto-link
>   first-broker-login flow. Budget for re-linking SSO users.
> - "Delete stale clients" has a sting: recreated portal clients came back **missing
>   attributes** (e.g. `post.logout.redirect.uris`) and with **new defaults**
>   (`client_secret_basic`), which broke logout. Note Keycloak client updates **merge**
>   attributes — to clear one you must set it to empty explicitly; omitting it does not delete it.

---

## 5. Restore KCP and OpenFGA

### 5.1 Disable the IPC webhook

```shell
KUBECONFIG=.secret/kcp/admin.kubeconfig kubectl \
  --server="https://localhost:8443/clusters/root:platform-mesh-system" \
  delete ValidatingWebhookConfiguration \
  identityproviderconfiguration-validator.webhooks.core.platform-mesh.io
```

> **🔧 Field note**
> Same intent on a real cluster — just substitute the front-proxy endpoint and super-admin
> cert for `localhost:8443`.

### 5.2 Recreate organizations and accounts

Create organizations and accounts via the browser (e.g., `default` org and its sub-accounts). The operator provisions workspace infrastructure — this must complete before restoring data.

> **🔧 Field note — the largest gap: shells come back, the contents don't**
> "Create via the browser" doesn't scale past a couple of orgs, and on a real cluster it hides
> the single biggest gotcha of the migration: the rebuild recreates org **shells** but **not**
> their **sub-accounts**, and **not the provider workspace tree** (`root:providers` and every
> provider under it). Neither is mentioned here; both had to be restored from backup as Account
> CRs / Workspace objects, separately and by hand.
> Two more that will bite anyone:
> - **Creator stamping.** Applying an Account CR with a **super-admin cert** stamps
>   `spec.creator = <that admin identity>`. The owner-Invite then tries to create a Keycloak
>   user from that as an email, fails email validation, and the **workspace hangs in
>   `Initializing`**. Fix a stuck account by patching `spec.creator` back to the backup value
>   and deleting the bad Invite so it regenerates. (To avoid the bad stamp in the first place,
>   apply the CR as the real owner via `kubectl --as=<owner-email>` — but that needs the owner
>   to hold apply RBAC in the workspace; if they don't, fall back to super-admin apply + the
>   creator-patch.)
> - **The account-operator must actually be watching.** Ours came up with an **empty**
>   `--kcp-api-export-endpoint-slice-name` flag, so it enumerated zero workspaces and
>   reconciled nothing — Account CRs just sat with no status. Set that flag (chart value) or
>   nothing in this section reconciles.
> - **Provider kubeconfig certs expire — and the error lies.** After re-creating the provider
>   tree, the `*-provider` HelmReleases may report `Unauthorized` ("could not determine release
>   state"). This usually is **not** RBAC or a missing workspace: the per-provider kubeconfig
>   client certs are **static** (minted by Helm `genSignedCert`, ~90-day, no auto-renew), so on
>   an aged cluster they're simply expired by restore time. Check the secret cert `notAfter`.
>   Re-mint fresh certs (a same-`O`/`CN` cert is valid for any workspace path, so you can copy a
>   still-valid provider's kubeconfig and rewrite the path) and reconcile. Durable fix:
>   cert-manager-managed provider certs so this never recurs on restore.

### 5.3 Migrate OpenFGA tuples

Stop operators that reconcile tuples:

```shell
kubectl scale deployment/security-operator -n platform-mesh-system --replicas=0
kubectl scale deployment/account-operator -n platform-mesh-system --replicas=0
```

Run the migration (replaces old KCP cluster IDs with current ones, writes to OpenFGA):

```shell
docs/migration-0.3/migrate-openfga-tuples.sh <backup-dir> [output-dir]
```

Restore operators:

```shell
kubectl scale deployment/account-operator -n platform-mesh-system --replicas=1
kubectl scale deployment/security-operator -n platform-mesh-system --replicas=1
```

> **🔧 Field note — the re-ID is small, but ORDER it dead-last or authz silently breaks**
> `migrate-openfga-tuples.sh` writes via the `fga` CLI and needs Linux + PCRE `grep -P`. We
> reached OpenFGA over its **HTTP API** directly instead (write the new-ID tuples, then delete
> the old-ID ones), which sidesteps the CLI/Linux dependency. Most tuples are **name-based** —
> only the subset that embeds the 16-char KCP cluster-id actually needs remapping, so the re-ID
> is small and targeted, not a reload.
>
> **The sharp edge this step doesn't flag: the re-ID bakes in each account's _current_ KCP
> cluster-id, so it must run DEAD LAST — after every workspace is created/restored and stable.**
> If any workspace is (re-)created *after* the re-ID — org recreation, sub-account restore, a
> `spec.creator` patch, or any reconcile that re-creates a workspace — that workspace gets a
> **new** cluster-id and its re-ID'd tuples go **stale**. The authz webhook then checks the
> *live* id, finds no tuple, and returns **`Unauthorized`** on the account page even though the
> store, the model, and the user's owner-tuples all exist. (Our tell: exactly one account
> worked — the one that happened to be re-reconciled under the live id.) Derive the new ids from
> **live state at re-ID time**, never an earlier snapshot, and **verify per account** with an
> OpenFGA `Check(user:<owner>, owner, …account:<LIVE-cluster-id>/<acct>)` → `allowed:true`. Do
> not re-apply Account CRs or trigger workspace-recreating reconciles after the re-ID.
>
> Separately, the wipe drops the OpenFGA **model/schema**, not just the IDs — it's regenerated
> by the security-operator's generator. If that generator runs a **stale image** it emits *zero*
> models and a store stays a degenerate stub, so confirm the generator is on the 0.3 line. (A
> parent / `orgs`-level store can legitimately stay a minimal stub — that affects account-list
> visibility only — so don't gate verification on a fixed model type-count.)

### 5.4 Restore HttpBin resources

```shell
docs/migration-0.3/restore-kcp-resources.sh <export-dir>
```

> **🔧 Field note — this script restores ONLY httpbins**
> Important: `restore-kcp-resources.sh` restores **only `httpbins`**. Every other type —
> `accounts`, `accountinfos`, `stores`, `identityproviderconfigurations`,
> `authorizationmodels`, `invites` — is **commented out** in `USER_DATA_RESOURCES`. So despite
> its name and placement, this step does **not** restore tenant accounts, the provider tree, or
> authz; that is the §5.2 / §5.3 hand-work above. Consider either expanding the script to cover
> those types (with the §5.2 creator-stamping caveat) or relabeling the step so it's clear it
> only covers httpbins.

### 5.5 Re-enable the IPC webhook

The operator recreates it on next reconciliation, or restart the security-operator.

> **🔧 Field note**
> Restarting the security-operator to let it recreate the webhook worked as described.

---

## 6. Post-restore

```shell
kubectl rollout restart deployment/rebac-authz-webhook -n platform-mesh-system
kubectl rollout status deployment/rebac-authz-webhook -n platform-mesh-system
kubectl -n platform-mesh-system rollout restart deployment/kubernetes-graphql-gateway-listener
kubectl -n platform-mesh-system rollout status deployment/kubernetes-graphql-gateway-listener
```

> **🔧 Field note — the portal needs three more things before it's usable**
> These restarts are necessary but not sufficient. On a real cluster the **portal** needed
> three additional fixes before login worked:
> - **Auth-refresh reload storm (code bug).** On an expired/invalid refresh token the portal
>   server cleared the cookie and returned an empty **2xx** instead of a 401, so the UI looped
>   (`/rest/config` → 500 → reload, ~1 Hz). This is a bug in `@openmfp/portal-server-lib`, not
>   config. Fix at source: classify `invalid_grant`/4xx → 401-once + clear cookie; transient →
>   503 keep cookie. Verify with `GET /rest/config` → 200 and a junk-cookie
>   `POST /rest/auth/refresh` → 401 (a 500 on `/rest/config` is the storm signature).
> - **Cookie scope.** The refresh cookie must be **host-only**. Setting `COOKIE_DOMAIN` to a
>   parent domain collides tokens across **per-realm org subdomains** → wrong-realm
>   `invalid_grant` → login loop. (The same library also needed `COOKIE_DOMAIN` /
>   `COOKIE_SAME_SITE` to be env-configurable at all.)
> - **Portal endpoint-shape skew (two failure sites).** The 0.3 portal and its content-service
>   address the gateway at a `/gateway/api/clusters/{cluster}/graphql` shape. If the deployed
>   HTTPRoute prefix/rewrite doesn't match, two things break: the **org-list query 404s** (empty
>   org dropdown), and the **content / users page renders blank** (the content-service's rewrite
>   no-ops against the deployed URL — the data is actually present). Both are routing/rewrite
>   mismatches, not missing data. Align the gateway route prefix and rewrite target with the
>   portal image's expected shape.

---

## 7. Verification

```shell
task test:portal-e2e
```

> **🔧 Field note — test the user path, not the controller statuses**
> `task test:portal-e2e` is local-only. On a real cluster we verified with: the KCP resource
> validator at **EXIT 0**, workspace / HelmRelease counts matching expectations, and — the one
> that actually matters — a **functional browser login**: pick an org, confirm the dropdown
> returns data, and confirm there's no reload storm.
> The trap this guards against: the rebuild can report **all-green** (HelmReleases Ready,
> workspaces Ready) while the platform is still **functionally broken** — accounts returning
> `Unauthorized`, SSO logins failing on "account already exists", the marketplace UI blank.
> **"Structurally Ready" is not "usable."** Exercise the user path explicitly — and in
> particular (per §5.3) confirm a sample account's OpenFGA owner-`Check` resolves against its
> **live** cluster-id, since a store-level model validator passes without exercising per-account
> authz.
