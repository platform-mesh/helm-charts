import { readFileSync, writeFileSync } from 'node:fs';
import dns from 'node:dns/promises';
import { execFileSync } from 'node:child_process';

import { expect } from '@playwright/test';

import {
  accountReadyTimeoutSeconds,
  inviteName,
  keycloakAdminPassword,
  keycloakAdminUser,
  keycloakBaseUrl,
  kubeconfigSmokeConfigMapName,
  newOrgName,
  primaryUser,
  testAccountName,
  type TestUser,
} from './constants';
import { logStep } from './log';
import { runAdminKubectl, runKubectlWithKubeconfig } from './runtime';

function waitForAccountReady(): void {
  logStep(`waitForAccountReady:start account=${testAccountName} timeout=${accountReadyTimeoutSeconds}s`);
  runAdminKubectl([
    'wait',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}`,
    '--for=condition=Ready',
    `--timeout=${accountReadyTimeoutSeconds}s`,
    `accounts.core.platform-mesh.io/${testAccountName}`,
  ]);
  logStep(`waitForAccountReady:done account=${testAccountName}`);
}

function waitForAccountExists(): void {
  logStep(`waitForAccountExists:start account=${testAccountName} timeout=${accountReadyTimeoutSeconds}s`);
  runAdminKubectl([
    'wait',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}`,
    '--for=jsonpath={.metadata.name}',
    `--timeout=${accountReadyTimeoutSeconds}s`,
    `accounts.core.platform-mesh.io/${testAccountName}`,
  ]);
  logStep(`waitForAccountExists:done account=${testAccountName}`);
}

function waitForAccountDeleted(): void {
  logStep(`waitForAccountDeleted:start account=${testAccountName} timeout=${accountReadyTimeoutSeconds}s`);
  runAdminKubectl([
    'wait',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}`,
    '--for=delete',
    `--timeout=${accountReadyTimeoutSeconds}s`,
    `accounts.core.platform-mesh.io/${testAccountName}`,
  ]);
  logStep(`waitForAccountDeleted:done account=${testAccountName}`);
}

function ensureInvitedUserExists(user: TestUser): void {
  logStep(`ensureInvitedUserExists:start email=${user.email}`);

  const manifest = [
    'apiVersion: core.platform-mesh.io/v1alpha1',
    'kind: Invite',
    'metadata:',
    `  name: ${inviteName}`,
    'spec:',
    `  email: ${user.email}`,
    '',
  ].join('\n');

  runAdminKubectl([
    'apply',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}`,
    '-f',
    '-',
  ], manifest);

  runAdminKubectl([
    'wait',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}`,
    '--for=condition=Ready',
    `--timeout=${accountReadyTimeoutSeconds}s`,
    `invites.core.platform-mesh.io/${inviteName}`,
  ]);

  logStep(`ensureInvitedUserExists:done email=${user.email}`);
}

function normalizeDownloadedKubeconfig(kubeconfigPath: string): void {
  const original = readFileSync(kubeconfigPath, 'utf8');
  let normalized = original.replace(
    /\n(\s+)certificate-authority-data: .+\n/,
    '\n$1insecure-skip-tls-verify: true\n',
  );

  if (!normalized.includes('--insecure-skip-tls-verify')) {
    normalized = normalized.replace(
      /(\s+- --oidc-extra-scope=email\n)/,
      `$1          - --insecure-skip-tls-verify\n`,
    );
  }

  if (!normalized.includes('--grant-type=password')) {
    normalized = normalized.replace(
      /(\s+- --oidc-client-id=.*\n)/,
      `$1          - --grant-type=password\n          - --username=${primaryUser.email}\n          - --password=${primaryUser.password}\n`,
    );
  }

  if (normalized !== original) {
    writeFileSync(kubeconfigPath, normalized, 'utf8');
  }
}

function extractOidcClientId(kubeconfigPath: string): string {
  const kubeconfig = readFileSync(kubeconfigPath, 'utf8');
  const match = kubeconfig.match(/--oidc-client-id=([^\n]+)/);
  if (!match) {
    throw new Error(`Unable to find OIDC client ID in ${kubeconfigPath}`);
  }

  return match[1].trim();
}

async function ensurePortalHostnameResolves(): Promise<void> {
  try {
    await dns.lookup('portal.localhost');
  } catch {
    throw new Error('portal.localhost must resolve locally for the kubeconfig smoke test. Add "127.0.0.1 portal.localhost" to /etc/hosts.');
  }
}

function keycloakApiRequest(method: 'GET' | 'POST' | 'PUT', url: string, body?: string, token?: string): string {
  const args = ['-sk', '-X', method, url];

  if (token) {
    args.push('-H', `Authorization: Bearer ${token}`);
  }

  if (body) {
    args.push('-H', 'content-type: application/json', '--data', body);
  }

  return execFileSync('curl', args, { encoding: 'utf8' }).trim();
}

function getKeycloakAdminToken(): string {
  const response = execFileSync('curl', [
    '-sk',
    '-X',
    'POST',
    `${keycloakBaseUrl}/realms/master/protocol/openid-connect/token`,
    '-H',
    'content-type: application/x-www-form-urlencoded',
    '--data',
    `grant_type=password&client_id=admin-cli&username=${encodeURIComponent(keycloakAdminUser)}&password=${encodeURIComponent(keycloakAdminPassword)}`,
  ], { encoding: 'utf8' }).trim();

  const parsed = JSON.parse(response);
  if (!parsed.access_token) {
    throw new Error(`Unable to get Keycloak admin token: ${response}`);
  }

  return parsed.access_token;
}

function ensureKubectlClientAllowsDirectGrants(clientId: string): void {
  const token = getKeycloakAdminToken();
  const response = keycloakApiRequest(
    'GET',
    `${keycloakBaseUrl}/admin/realms/default/clients?clientId=${encodeURIComponent(clientId)}`,
    undefined,
    token,
  );
  const clients = JSON.parse(response);

  if (!Array.isArray(clients) || clients.length === 0) {
    throw new Error(`Unable to find Keycloak client ${clientId}`);
  }

  const client = clients[0];
  if (client.directAccessGrantsEnabled === true) {
    return;
  }

  client.directAccessGrantsEnabled = true;
  keycloakApiRequest(
    'PUT',
    `${keycloakBaseUrl}/admin/realms/default/clients/${client.id}`,
    JSON.stringify(client),
    token,
  );
}

async function verifyDownloadedKubeconfig(kubeconfigPath: string): Promise<void> {
  logStep(`verifyDownloadedKubeconfig:start path=${kubeconfigPath}`);
  await ensurePortalHostnameResolves();
  ensureKubectlClientAllowsDirectGrants(extractOidcClientId(kubeconfigPath));

  const manifest = [
    'apiVersion: v1',
    'kind: ConfigMap',
    'metadata:',
    `  name: ${kubeconfigSmokeConfigMapName}`,
    '  namespace: default',
    'data:',
    '  smoke: ok',
    '',
  ].join('\n');

  runKubectlWithKubeconfig(kubeconfigPath, ['auth', 'can-i', 'create', 'configmaps', '-n', 'default']);
  runKubectlWithKubeconfig(kubeconfigPath, ['apply', '-f', '-'], manifest);

  const configMapName = runKubectlWithKubeconfig(kubeconfigPath, ['get', 'configmap', kubeconfigSmokeConfigMapName, '-n', 'default', '-o', 'jsonpath={.metadata.name}']);
  expect(configMapName).toBe(kubeconfigSmokeConfigMapName);

  runKubectlWithKubeconfig(kubeconfigPath, ['delete', 'configmap', kubeconfigSmokeConfigMapName, '-n', 'default', '--ignore-not-found=true']);
  logStep(`verifyDownloadedKubeconfig:done path=${kubeconfigPath}`);
}

export {
  waitForAccountReady,
  waitForAccountExists,
  waitForAccountDeleted,
  ensureInvitedUserExists,
  normalizeDownloadedKubeconfig,
  verifyDownloadedKubeconfig,
};
