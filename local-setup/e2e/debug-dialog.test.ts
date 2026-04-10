import test, { expect } from '@playwright/test';

import {
  primaryUser,
  ensureWelcomePage,
  switchToOrganization,
  logStep,
} from './helpers/portal';

import { testAccountName } from './helpers/constants';

test.describe('Debug httpbins', () => {
  test.setTimeout(60000);

  test('inspect httpbins page', async ({ page }) => {
    await ensureWelcomePage(page, primaryUser);
    await switchToOrganization(page, primaryUser, false);

    const orgName = process.env.ORG_NAME || 'default';

    // Navigate to httpbins page directly
    const url = `https://${orgName}.portal.localhost:8443/home/accounts/${testAccountName}/orchestrate_platform-mesh_io_httpbins`;
    logStep(`debug:navigating to ${url}`);
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);

    await page.screenshot({ path: 'debug-httpbins.png', fullPage: true });
    logStep(`debug:url=${page.url()}`);

    // Find all data-testid attributes
    const dataTestIds = await page.evaluate(() => {
      const results: string[] = [];
      document.querySelectorAll('[data-testid]').forEach(el => {
        results.push(`tag=${el.tagName.toLowerCase()} data-testid=${el.getAttribute('data-testid')}`);
      });
      return results;
    });
    console.log('=== data-testid attributes ===');
    for (const line of dataTestIds) console.log(line);

    // Find all comboboxes
    const comboboxes = page.getByRole('combobox');
    const count = await comboboxes.count();
    logStep(`debug:combobox-count=${count}`);
    for (let i = 0; i < count; i++) {
      const text = await comboboxes.nth(i).textContent().catch(() => '');
      logStep(`debug:combobox[${i}] text="${text?.trim()}"`);
    }

    logStep('debug:done');
  });
});
