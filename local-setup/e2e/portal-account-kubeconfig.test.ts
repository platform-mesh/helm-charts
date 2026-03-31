import test from '@playwright/test';

import {
  primaryUser,
  ensureWelcomePage,
  switchToOrganization,
  ensureExampleHttpbinProviderWorkspace,
  ensureAccountExists,
  downloadAccountKubeconfig,
  logStep,
} from './helpers/portal';

test.describe('Portal Account Kubeconfig', () => {
  test.setTimeout(600000);

  test('Account kubeconfig download flow', async ({ page }) => {
    logStep('test:account-kubeconfig:start');
    await ensureWelcomePage(page, primaryUser);
    await switchToOrganization(page, primaryUser, true);
    ensureExampleHttpbinProviderWorkspace();

    await ensureAccountExists(page);
    await downloadAccountKubeconfig(page);
    logStep('test:account-kubeconfig:done');
  });
});
