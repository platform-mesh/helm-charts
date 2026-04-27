import { expect, Page } from '@playwright/test';

import { testAccountName } from './constants';
import { logStep, portalOrgUrl } from './log';

const marketplaceFrameSelector = 'iframe[src*="/ui/marketplace/ui/#/marketplace"]';

async function waitForMarketplaceFrame(page: Page): Promise<void> {
  const marketplaceFrame = page.locator(marketplaceFrameSelector).first();
  await expect(marketplaceFrame).toBeVisible({ timeout: 30000 });
  await expect(marketplaceFrame).toHaveAttribute('src', /\/ui\/marketplace\/ui\/#\/marketplace/);
}

async function openOrganizationMarketplace(page: Page): Promise<void> {
  const marketplaceUrl = portalOrgUrl('/home/marketplace');
  logStep(`openOrganizationMarketplace:url=${marketplaceUrl}`);
  await page.goto(marketplaceUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});
  await waitForMarketplaceFrame(page);
}

async function openAccountMarketplace(page: Page): Promise<void> {
  const marketplaceUrl = portalOrgUrl(`/home/accounts/${testAccountName}/marketplace`);
  logStep(`openAccountMarketplace:url=${marketplaceUrl}`);
  await page.goto(marketplaceUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});
  await waitForMarketplaceFrame(page);
}

export {
  openOrganizationMarketplace,
  openAccountMarketplace,
};
