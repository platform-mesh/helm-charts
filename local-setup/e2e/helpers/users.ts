import { Page } from '@playwright/test';

import { logStep } from './log';

async function expectUnauthorizedAccountAccess(page: Page, accountUrl: string): Promise<void> {
  logStep(`expectUnauthorizedAccountAccess:start url=${accountUrl}`);
  await page.goto(accountUrl, { waitUntil: 'domcontentloaded' });

  if (/\/error\/403(?:$|[/?#])/.test(page.url())) {
    logStep(`expectUnauthorizedAccountAccess:denied-via=url-403 final-url=${page.url()}`);
    logStep(`expectUnauthorizedAccountAccess:done url=${accountUrl}`);
    return;
  }

  const forbiddenMessage = page.getByText(/not authorized|unauthorized|forbidden|access denied/i).first();

  const denied = await Promise.race([
    page.waitForURL(/\/error\/403(?:$|[/?#])/, { timeout: 30000 }).then(() => 'url-403'),
    forbiddenMessage.waitFor({ state: 'visible', timeout: 30000 }).then(() => 'message'),
  ]).catch(() => null);

  if (!denied) {
    const pageText = await page.locator('body').innerText().catch(() => '');
    throw new Error(`Expected unauthorized access denial for ${accountUrl}, final URL=${page.url()}, body=${pageText.slice(0, 500)}`);
  }

  logStep(`expectUnauthorizedAccountAccess:denied-via=${denied} final-url=${page.url()}`);
  logStep(`expectUnauthorizedAccountAccess:done url=${accountUrl}`);
}

export { expectUnauthorizedAccountAccess };
