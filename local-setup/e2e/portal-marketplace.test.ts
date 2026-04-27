import test from '@playwright/test';

import {
  primaryUser,
  ensureWelcomePage,
  switchToOrganization,
  ensureAccountExists,
  openOrganizationMarketplace,
  openAccountMarketplace,
  logStep,
} from './helpers/portal';

test.describe('Portal Marketplace', () => {
  test.setTimeout(600000);

  test('Marketplace integration is reachable from org and account routes', async ({ page }) => {
    logStep('test:marketplace:start');
    await ensureWelcomePage(page, primaryUser);
    await switchToOrganization(page, primaryUser, true);

    await openOrganizationMarketplace(page);
    await ensureAccountExists(page);
    await openAccountMarketplace(page);
    logStep('test:marketplace:done');
  });
});
