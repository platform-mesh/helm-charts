import test from '@playwright/test';

import {
  primaryUser,
  ensureWelcomePage,
  switchToOrganization,
  ensureExampleHttpbinProviderWorkspace,
  ensureAccountExists,
  deleteAccount,
  logStep,
} from './helpers/portal';

test.describe('Portal Account Deletion', () => {
  test.setTimeout(600000);

  test('Account deletion flow', async ({ page }) => {
    logStep('test:account-deletion:start');
    await ensureWelcomePage(page, primaryUser);
    await switchToOrganization(page, primaryUser, true);
    ensureExampleHttpbinProviderWorkspace();

    const accountUrl = await ensureAccountExists(page);
    await deleteAccount(page, accountUrl);
    logStep('test:account-deletion:done');
  });
});
