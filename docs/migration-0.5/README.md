# Migration guide 0.4 → 0.5

## braking changes in 0.5



### Generate test data

Run before migration to create durable pre-migration resources (org accounts, sub-accounts, HTTPBins)
that can be verified before and after.

```shell
kind export kubeconfig --name platform-mesh
KUBECONFIG_KCP=/home/akafazov/src/github.com/platform-mesh/helm-charts/.secret/kcp/admin.kubeconfig \
  docs/migration-0.4/create-test-data.sh
```


### Backup (for comparison)

```shell
# 0.3 backup
BACKUPDIR=backup/0.4
local-setup/scripts/keycloak_backup.sh $BACKUPDIR/keycloak/postgres
local-setup/scripts/keycloak_export_realms.sh $BACKUPDIR/keycloak/realms
local-setup/scripts/fga_backup.sh $BACKUPDIR/openfga
local-setup/scripts/etcd_backup.sh $BACKUPDIR/etcd
KUBECONFIG_KCP=.secret/kcp/admin.kubeconfig local-setup/scripts/export-resources.sh $BACKUPDIR
```
KUBECONFIG_KCP=/home/akafazov/src/github.com/platform-mesh/helm-charts/.secret/kcp/admin.kubeconfig local-setup/scripts/export-resources.sh $BACKUPDIR

### 3. Remove 0.4-only resources

```shell
kubectl delete platformmeshes platform-mesh -n platform-mesh-system
kubectl delete platformmeshoperators --all
kubectl delete resourcegraphdefinitions platform-mesh-operator
kubectl delete crd platformmeshoperators.kro.run

kubectl delete resource --all -n platform-mesh-system
kubectl delete component platform-mesh -n platform-mesh-system
kubectl delete repositories platform-mesh -n platform-mesh-system
kubectl delete helmreleases --all -n platform-mesh-system
```

### 4. Install 0.5

```shell
git checkout 0.5.0

# OCM component (new namespace)
kubectl apply -k local-setup/kustomize/base/ocm-k8s-toolkit
kubectl apply -k local-setup/kustomize/base/kro
kubectl apply -k local-setup/kustomize/components/ocm   # set SEMVER to 0.5.0 manually

# platform-mesh-operator
kubectl apply -k local-setup/kustomize/base/rgd
kubectl apply -k local-setup/kustomize/components/platform-mesh-operator
kubectl apply -k local-setup/kustomize/overlays/platform-mesh-resource

# wait for PlatformMesh to become Ready
kubectl get platformmesh -A -w
```

### 5. Restore stateful data

```shell
# Keycloak — restores into cnpg cluster (platform-mesh-pg-1)
BACKUP_DIR=backup/0.4/keycloak/postgres docs/migration-0.4/keycloak_restore.sh

# OpenFGA — restores into openfga-postgres-0
BACKUP_DIR=backup/0.4/openfga/postgres docs/migration-0.4/openfga_restore.sh
```

#### 5.1 fix client secret for IdP resources in kcp

Some `IdentityProviderConfiguration` resources in kcp's `:root:orgs` workspace might have an invalid state:

```yaml
- lastTransitionTime: "2026-09-13T12:06:29Z"
  message: 'failed to create or update realm: failed to create realm: Post "https://portal.localhost:8443/keycloak/admin/realms": oauth2: "unauthorized_client" "Invalid client or Invalid client credentials"'
  observedGeneration: 1
  reason: Error
  status: "False"
  type: IdentityProviderConfiguration
- lastTransitionTime: "2026-09-13T12:06:29Z"
  message: one or more subroutines encountered an error
  observedGeneration: 1
  reason: Error
  status: "False"
  type: Ready
```

Is is due to the client secrets having different values than the one's in keycloak. To fix this, update the secret in kcp named `portal-client-secret-test-${orgname}-${orgname}` to contain the same secret as the corresponding keycloak application in the appropriate realm.

### 6. Verify

Check that the portal is functional and the test data created in step 1 is intact.

### 7. Back up 0.5

```shell
BACKUPDIR=backup/0.5
local-setup/scripts/keycloak_backup.sh $BACKUPDIR/keycloak/postgres
docs/migration-0.4/keycloak_export_realms.sh $BACKUPDIR/keycloak/realms
local-setup/scripts/fga_backup.sh $BACKUPDIR/openfga
local-setup/scripts/etcd_backup.sh $BACKUPDIR/etcd
KUBECONFIG_KCP=.secret/kcp/admin.kubeconfig local-setup/scripts/export-resources.sh $BACKUPDIR
```
