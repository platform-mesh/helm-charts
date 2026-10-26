# Migrate OpenFGA to the shared CNPG cluster

## What this migration does

OpenFGA ships with an optional bundled PostgreSQL StatefulSet (`openfga-postgres-0`). This migration moves OpenFGA's data to the shared CNPG cluster (`platform-mesh-pg`) that already hosts Keycloak's database.

**This is a server consolidation, not a schema migration.** The OpenFGA schema and data model are identical. Only the PostgreSQL server hosting the data changes.

## When to perform this migration

Perform this migration if your profile has `postgresql.enabled: true` in the `openfga` section. This is the default for the KIND profile.

If your profile already points OpenFGA at an external PostgreSQL instance (`postgresql.enabled: false`), no migration is needed.

## Prerequisites

The shared CNPG cluster must already be provisioning an `openfga` database with an `openfga` role. Verify that your profile's `infra` values include:

```yaml
cnpg:
  enabled: true
  roles:
    openfga:
      username: openfga
      password: "<strong-random-password>"
  databases:
    - name: openfga
      owner: openfga
```

If these are absent, add them and wait for the `openfga-db` Database CR to report `status.applied: true` before proceeding.

## Migration procedure

### 1. Backup

Run this **before** changing the profile, while `openfga-postgres-0` is still running:

```shell
mkdir -p backup/openfga-migration
BACKUPDIR=backup/openfga-migration
./openfga_migrate.sh backup $BACKUPDIR
```

The backup is saved as `$BACKUPDIR/backup-<timestamp>.sql`. Note the filename — you will need it in step 3.

### 2. Edit your profile

Export your current profile if you don't have a local copy:

```shell
kubectl get configmap platform-mesh-profile -n platform-mesh-system -o yaml > my-profile.yaml
```

In the exported file, replace the `openfga.values` block with the CNPG configuration. The key changes are:

- Set `postgresql.enabled: false` to remove the bundled postgres pod
- Replace `datastore.uri` with the CNPG connection string (TLS, no embedded credentials)
- Add `datastore.existingSecret` and `secretKeys` to supply credentials from the CNPG secret
- Add `extraVolumes` / `extraVolumeMounts` for the CNPG CA certificate
- Add `extraVolumeMounts` to the `migrate` section so the migration init container can also read the cert

The resulting `openfga.values` section should look like this (merge with any other values you have, such as `image.tag`, `replicaCount`, etc.):

```yaml
openfga:
  values:
    postgresql:
      enabled: false
    datastore:
      existingSecret: cnpg-openfga-user
      secretKeys:
        passwordKey: password
        usernameKey: username
      uri: "postgres://openfga@platform-mesh-pg-rw.platform-mesh-system.svc.cluster.local:5432/openfga?sslmode=verify-full&sslrootcert=/etc/openfga/cnpg-ca/ca.crt"
    # ↑ datastore block ends here
    # ↓ extraVolumes/extraVolumeMounts are siblings of datastore, NOT nested inside it
    extraVolumes:
      - name: cnpg-ca
        secret:
          secretName: platform-mesh-pg-ca
    extraVolumeMounts:
      - mountPath: /etc/openfga/cnpg-ca
        name: cnpg-ca
        readOnly: true
    migrate:
      extraVolumeMounts:
        - mountPath: /etc/openfga/cnpg-ca
          name: cnpg-ca
          readOnly: true
```

> **Common mistake**: placing `extraVolumes`/`extraVolumeMounts` inside the `datastore:` block. The OpenFGA chart does not recognise those keys under `datastore:` and silently ignores them, leaving the CA cert unmounted and every pod start failing with `unable to read CA file`. Confirm the indentation: `extraVolumes:` must align with `datastore:`, not with `existingSecret:`.

Apply the updated profile ConfigMap:

```shell
kubectl apply -f my-profile.yaml
```

Then trigger PMO to reconcile:

```shell
kubectl annotate platformmesh platform-mesh -n platform-mesh-system \
  reconcile.fluxcd.io/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```

Wait for the CNPG `openfga-db` Database CR to be provisioned:

```shell
kubectl wait database/openfga-db -n platform-mesh-system \
  --for=jsonpath='.status.applied'=true \
  --timeout=300s
```

At this point the new OpenFGA pod may fail to start with `permission denied for schema public` in its `migrate-database` init container. This is expected: PostgreSQL 15+ does not automatically grant CREATE on the `public` schema to the database owner, and the CNPG Role CR does not include a schema-level grant. The restore step in step 3 fixes this as part of its operation — proceed directly.

### 3. Restore

Run the restore now — do not wait for the OpenFGA pod to become Ready first. The restore script resets schema permissions as part of its operation, which unblocks the `migrate-database` init container:

```shell
docs/migration-openfga-cnpg/openfga_migrate.sh restore $BACKUPDIR/backup-<timestamp>.sql
```

The script will:

1. Wait for the CNPG primary pod (`platform-mesh-pg-1`) to be Ready
2. Wait for the `openfga-db` Database CR to report applied (`status.applied: true`)
3. Scale OpenFGA down to prevent concurrent access during restore
4. Drop and recreate the `public` schema in the `openfga` database
5. Restore the backup
6. Reassign table ownership from `postgres` to `openfga` (tables were created by the `postgres` superuser in the old pod; the `openfga` role in CNPG must own them to run future migrations)
7. Grant table and sequence access to both `openfga` and `PUBLIC` — the OpenFGA migration init container connects as a user other than `openfga` (the CNPG-managed role), so `PUBLIC` is required for the init container's schema migration to succeed
8. Scale OpenFGA back up and wait for rollout

### 4. Verify

Check that authorization data is intact. Use the OpenFGA API or portal to confirm stores and tuples are present.

### 5. Future backups

Once migrated, OpenFGA data lives in the shared CNPG cluster. Back up with:

```shell
kubectl exec -n platform-mesh-system platform-mesh-pg-1 -- \
  pg_dump -U postgres -d openfga > backup/openfga-$(date +%F-%T).sql
```
