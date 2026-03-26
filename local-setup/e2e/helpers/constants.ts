import path from 'node:path';

const portalBaseUrl = 'https://portal.localhost:8443/';
const runId = process.env.TEST_RUN_ID || `${Date.now()}`.slice(-8);
const newOrgName = process.env.ORG_NAME || 'default';
const testAccountName = process.env.TEST_ACCOUNT_NAME || `testaccount-${runId}`;
const testNamespaceName = process.env.TEST_NAMESPACE_NAME || `test-${runId}`;
const defaultHttpBinName = process.env.DEFAULT_HTTPBIN_NAME || `test-default-${runId}`;
const testNamespaceHttpBinName = process.env.TEST_NAMESPACE_HTTPBIN_NAME || `test-namespace-${runId}`;
const kubeconfigSmokeConfigMapName = process.env.KUBECONFIG_SMOKE_CONFIGMAP_NAME || 'oidc-kubeconfig-smoke-test';
const inviteName = process.env.INVITE_NAME || `invite-${runId}`;
const accountReadyTimeoutSeconds = process.env.ACCOUNT_READY_TIMEOUT_SECONDS || '180';
const orgReadyTimeoutSeconds = process.env.ORG_READY_TIMEOUT_SECONDS || '300';
const keycloakBaseUrl = process.env.KEYCLOAK_BASE_URL || 'https://portal.localhost:8443/keycloak';
const keycloakAdminUser = process.env.KEYCLOAK_ADMIN_USER || 'keycloak-admin';
const keycloakAdminPassword = process.env.KEYCLOAK_ADMIN_PASSWORD || 'admin';
const repoRoot = path.resolve(process.cwd(), '..', '..');
const adminKubeconfigPath = process.env.ADMIN_KUBECONFIG || path.join(repoRoot, '.secret/kcp/admin.kubeconfig');
const runtimeKubeconfigPath = process.env.RUNTIME_KUBECONFIG || path.join(repoRoot, '.secret/platform-mesh.kubeconfig');
const infraKubeconfigPath = process.env.INFRA_KUBECONFIG || path.join(repoRoot, '.secret/platform-mesh-infra.kubeconfig');
const httpbinProviderManifestPath = path.join(repoRoot, 'local-setup', 'example-data', 'root', 'providers', 'httpbin-provider');
const exampleDataOverlayPath = path.join(repoRoot, 'local-setup', 'kustomize', 'overlays', 'example-data');

type TestUser = {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  keycloakPassword: string;
};

const primaryUser: TestUser = {
  email: process.env.TEST_USER_EMAIL || 'username@sap.com',
  password: process.env.TEST_USER_PASSWORD || 'MyPass1234',
  firstName: process.env.TEST_USER_FIRST_NAME || 'Firstname',
  lastName: process.env.TEST_USER_LAST_NAME || 'Lastname',
  keycloakPassword: process.env.TEST_USER_KEYCLOAK_PASSWORD || 'password',
};

const invitedUser: TestUser = {
  email: process.env.INVITED_USER_EMAIL || 'inviteusername@sap.com',
  password: process.env.INVITED_USER_PASSWORD || 'MyPass1234',
  firstName: process.env.INVITED_USER_FIRST_NAME || 'Invited',
  lastName: process.env.INVITED_USER_LAST_NAME || 'User',
  keycloakPassword: process.env.INVITED_USER_KEYCLOAK_PASSWORD || 'password',
};

export {
  portalBaseUrl,
  runId,
  newOrgName,
  testAccountName,
  testNamespaceName,
  defaultHttpBinName,
  testNamespaceHttpBinName,
  kubeconfigSmokeConfigMapName,
  inviteName,
  accountReadyTimeoutSeconds,
  orgReadyTimeoutSeconds,
  keycloakBaseUrl,
  keycloakAdminUser,
  keycloakAdminPassword,
  repoRoot,
  adminKubeconfigPath,
  runtimeKubeconfigPath,
  infraKubeconfigPath,
  httpbinProviderManifestPath,
  exampleDataOverlayPath,
  primaryUser,
  invitedUser,
};
export type { TestUser };
