import test, { expect, Page } from '@playwright/test';

import { inviteUserToOrg, selectExistingOrganization, ensureWelcomePage } from './helpers/auth';
import { invitedUser, primaryUser, runId } from './helpers/constants';
import { logStep } from './helpers/log';
import { ensureAccountExists } from './helpers/account';
import {
  type ShardName,
  preCreateShardedOrgWorkspace,
  preCreateShardedAccountWorkspace,
  waitForShardedAccountReady,
  waitForWorkspaceOnShard,
  verifyShardAssignments,
} from './helpers/sharding';

// ORG_SHARD controls which shard to create the org on
const ORG_SHARD: ShardName = (process.env.SHARDING_ORG_SHARD as ShardName) || 'triton';
const ACCOUNT_SHARDS: ShardName[] = ['triton', 'root'];

const orgName = `org-${ORG_SHARD}-${runId}`;
const accounts = ACCOUNT_SHARDS.map((shard) => ({
  name: `acc-${shard}-${runId}`,
  shard,
}));

async function completeKeycloakSetup(page: Page): Promise<void> {
  // Handle password update flow
  const newPasswordField = page.getByRole('textbox', { name: 'New Password' });
  if (await newPasswordField.isVisible().catch(() => false)) {
    await newPasswordField.fill(primaryUser.password);
    await page.getByRole('textbox', { name: 'Confirm password' }).fill(primaryUser.password);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  // Handle profile update flow
  const firstNameField = page.getByRole('textbox', { name: 'First name' });
  if (await firstNameField.isVisible().catch(() => false)) {
    await firstNameField.fill(primaryUser.firstName);
    await page.getByRole('textbox', { name: 'Last name' }).fill(primaryUser.lastName);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  // Handle "back to application" link
  const backLink = page.getByRole('link', { name: 'Back to Application' });
  if (await backLink.isVisible().catch(() => false)) {
    await backLink.click();
  }

  // Handle redirect back to login
  const emailField = page.getByRole('textbox', { name: 'Email' });
  if (await emailField.isVisible().catch(() => false)) {
    await emailField.fill(primaryUser.email);
    await page.getByRole('textbox', { name: 'Password' }).fill(primaryUser.password);
    await page.getByRole('button', { name: 'Sign In' }).click();
  }

  await page.waitForURL(`https://${orgName}.portal.localhost:8443/**`, { timeout: 30000 });
  await expect(page.getByText("Welcome! Let's get started.", { exact: true })).toBeVisible({ timeout: 15000 });
}

test.describe('Home Page', () => {
  test.setTimeout(600000);

  test('Register and navigate to portal', async ({ page }) => {
    logStep(`setup:start org=${orgName} shard=${ORG_SHARD}`);

    // 1. Register/login
    await ensureWelcomePage(page, primaryUser);

    // 2. Pre-create org workspace with shard selector
    preCreateShardedOrgWorkspace(orgName, ORG_SHARD);

    // 3. Create org via UI
    await page.locator('[test-id="organization-management-input"]').locator('input').fill(orgName);
    await page.locator('[test-id="organization-management-onboard-button"]').locator('button').click();

    // 4. Wait for org workspace to be ready on shard
    waitForWorkspaceOnShard(orgName, 'root:orgs', ORG_SHARD);

    // 5. Switch to org
    await selectExistingOrganization(page, orgName);
    const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button');
    await expect(switchButton).toBeEnabled({ timeout: 100000 });
    await switchButton.click();

    // 6. Complete Keycloak login
    await page.getByRole('textbox', { name: 'Email' }).fill(primaryUser.email);
    await page.getByRole('textbox', { name: 'Password' }).fill(primaryUser.keycloakPassword);
    await page.getByRole('button', { name: 'Sign In' }).click();
    await completeKeycloakSetup(page);

    // 7. Invite user
    await inviteUserToOrg(page, invitedUser.email);

    // 8. Create accounts with shard selectors
    for (const account of accounts) {
      preCreateShardedAccountWorkspace(account.name, orgName, account.shard);
      await ensureAccountExists(page, orgName, account.name);
      waitForShardedAccountReady(account.name, orgName, account.shard);
      logStep(`setup:account-created ${account.name}@${account.shard}`);
    }

    // 9. Verify shard assignments
    verifyShardAssignments(orgName, ORG_SHARD, accounts);

    logStep(`setup:done org=${orgName}`);
  });
});
