import { readFileSync, writeFileSync } from 'node:fs';

import {
  accountReadyTimeoutSeconds,
  inviteName,
  newOrgName,
  primaryUser,
  testAccountName,
  type TestUser,
} from './constants';
import { logStep } from './log';
import { runAdminKubectl } from './runtime';

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
  let normalized = original
    .replace(/\n(\s+)certificate-authority-data: .+\n/g, '\n$1insecure-skip-tls-verify: true\n')
    .replace(/\n(\s+)certificate-authority: .+\n/g, '\n$1insecure-skip-tls-verify: true\n');

  if (!/\n\s+insecure-skip-tls-verify:\s*true\s*\n/.test(normalized)) {
    normalized = normalized.replace(
      /(\n\s+server: .+\n)/,
      `$1      insecure-skip-tls-verify: true\n`,
    );
  }

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

export {
  waitForAccountReady,
  waitForAccountExists,
  waitForAccountDeleted,
  ensureInvitedUserExists,
  normalizeDownloadedKubeconfig,
};
