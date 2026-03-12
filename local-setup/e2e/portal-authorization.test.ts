import test from '@playwright/test';

import {
  primaryUser,
  invitedUser,
  ensureWelcomePage,
  switchToOrganization,
  ensureExampleHttpbinProviderWorkspace,
  ensureInvitedUserExists,
  ensureAccountExists,
  expectUnauthorizedAccountAccess,
  logStep,
} from './helpers/portal';

test.describe('Portal Authorization with Multiple Users', () => {
  test.setTimeout(600000);

  test('Second user is denied account access', async ({ page, browser }) => {
    logStep('test:authorization:start');
    await ensureWelcomePage(page, primaryUser);
    await switchToOrganization(page, primaryUser, true);
    ensureExampleHttpbinProviderWorkspace();
    ensureInvitedUserExists(invitedUser);

    const accountUrl = await ensureAccountExists(page);

    const invitedUserContext = await browser.newContext({ ignoreHTTPSErrors: true });
    const invitedUserPage = await invitedUserContext.newPage();

    try {
      await ensureWelcomePage(invitedUserPage, invitedUser);
      await switchToOrganization(invitedUserPage, invitedUser, false);
      await expectUnauthorizedAccountAccess(invitedUserPage, accountUrl);
    } finally {
      await invitedUserContext.close();
    }

    logStep('test:authorization:done');
  });
});
