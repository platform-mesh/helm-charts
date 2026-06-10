import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import dns from 'node:dns/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

import { expect } from '@playwright/test';

import {
  accountReadyTimeoutSeconds,
  inviteName,
  keycloakAdminPassword,
  keycloakAdminUser,
  keycloakBaseUrl,
  kcpClusterServer,
  kcpRootCaPath,
  kcpUrl,
  kubeconfigSmokeConfigMapName,
  mkcertCaPath,
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
    kcpClusterServer(`root:orgs:${newOrgName}`),
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
    kcpClusterServer(`root:orgs:${newOrgName}`),
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
    kcpClusterServer(`root:orgs:${newOrgName}`),
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
    kcpClusterServer(`root:orgs:${newOrgName}`),
    '-f',
    '-',
  ], manifest);

  runAdminKubectl([
    'wait',
    '--server',
    kcpClusterServer(`root:orgs:${newOrgName}`),
    '--for=condition=Ready',
    `--timeout=${accountReadyTimeoutSeconds}s`,
    `invites.core.platform-mesh.io/${inviteName}`,
  ]);

  logStep(`ensureInvitedUserExists:done email=${user.email}`);
}

function readPemFile(filePath: string): string {
  if (!existsSync(filePath)) {
    throw new Error(`CA file not found at ${filePath}. Run local-setup before the kubeconfig e2e tests.`);
  }

  return readFileSync(filePath, 'utf8').trim();
}

function encodeCombinedCa(intermediatePem: string, rootCaPem: string): string {
  const combined = intermediatePem
    ? `${intermediatePem.trim()}\n${rootCaPem.trim()}\n`
    : `${rootCaPem.trim()}\n`;
  return Buffer.from(combined).toString('base64');
}

function appendKcpRootCa(content: string, rootCaPem: string): string {
  const caLineMatch = content.match(/^([ \t]*)certificate-authority-data:[ \t]*(.+)$/m);
  const indent = caLineMatch?.[1] ?? '    ';

  if (caLineMatch) {
    const intermediatePem = Buffer.from(caLineMatch[2].trim(), 'base64').toString('utf8');
    if (intermediatePem.includes(rootCaPem)) {
      return content;
    }

    const combinedCa = encodeCombinedCa(intermediatePem, rootCaPem);
    return content.replace(
      /^[ \t]*certificate-authority-data:[ \t]*.+$/m,
      `${indent}certificate-authority-data: ${combinedCa}`,
    );
  }

  const combinedCa = encodeCombinedCa('', rootCaPem);
  return content.replace(
    /^([ \t]*server: .+\n)/m,
    `${indent}certificate-authority-data: ${combinedCa}\n$1`,
  );
}

function configureOidcExecAuth(content: string, mkcertCa: string): string {
  let normalized = content.replace(/\s+- --insecure-skip-tls-verify\n/g, '');

  const certAuthorityArg = `          - --certificate-authority=${mkcertCa}\n`;
  if (normalized.includes('--certificate-authority=')) {
    return normalized;
  }

  if (normalized.includes('--oidc-issuer-url=')) {
    return normalized.replace(
      /(\s+- --oidc-issuer-url=[^\n]+\n)/,
      `$1${certAuthorityArg}`,
    );
  }

  if (normalized.includes('--oidc-client-id=')) {
    return normalized.replace(
      /(\s+- --oidc-client-id=[^\n]+\n)/,
      `$1${certAuthorityArg}`,
    );
  }

  return normalized;
}

function normalizeDownloadedKubeconfig(kubeconfigPath: string): void {
  const original = readFileSync(kubeconfigPath, 'utf8');
  let normalized = original.replace(/\r\n/g, '\n');

  normalized = normalized.replace(/^[ \t]*insecure-skip-tls-verify:.*\n/gm, '');
  normalized = appendKcpRootCa(normalized, readPemFile(kcpRootCaPath));
  normalized = configureOidcExecAuth(normalized, path.resolve(mkcertCaPath));

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
  const kcpApiHostname = new URL(kcpUrl).hostname;
  for (const hostname of ['portal.localhost', kcpApiHostname]) {
    try {
      await dns.lookup(hostname);
    } catch {
      throw new Error(`${hostname} must resolve locally for the kubeconfig smoke test. Add "127.0.0.1 ${hostname}" to /etc/hosts.`);
    }
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
  normalizeDownloadedKubeconfig(kubeconfigPath);
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

  const configMapName = runKubectlWithKubeconfig(
    kubeconfigPath,
    ['get', 'configmap', kubeconfigSmokeConfigMapName, '-n', 'default', '-o', 'jsonpath={.metadata.name}'],
  );
  expect(configMapName).toBe(kubeconfigSmokeConfigMapName);

  runKubectlWithKubeconfig(
    kubeconfigPath,
    ['delete', 'configmap', kubeconfigSmokeConfigMapName, '-n', 'default', '--ignore-not-found=true'],
  );
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
