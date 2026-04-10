import { existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { expect, Locator, Page } from '@playwright/test';

import { newOrgName, testAccountName } from './constants';
import { waitForAccountDeleted, waitForAccountExists, waitForAccountReady, normalizeDownloadedKubeconfig } from './backend';
import { clickRobust } from './httpbins';
import { logStep, portalOrgUrl } from './log';

async function openAccountsView(page: Page): Promise<void> {
  const createButton = page.locator('[test-id="generic-list-view-create-button"]');
  const heading = page.getByRole('heading', { name: 'Accounts', exact: true });
  const accountsUrl = portalOrgUrl('/home/accounts');

  logStep(`openAccountsView:navigate url=${accountsUrl}`);
  await page.goto(accountsUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});

  await Promise.race([
    createButton.waitFor({ state: 'visible', timeout: 15000 }).then(() => true),
    heading.waitFor({ state: 'visible', timeout: 15000 }).then(() => createButton.isVisible().catch(() => false)),
  ]).catch(() => false);

  await expect(createButton).toBeVisible({ timeout: 15000 });
}

async function ensureListRowVisible(page: Page, row: Locator): Promise<void> {
  for (let attempt = 0; attempt < 20; attempt++) {
    if (await row.isVisible().catch(() => false)) {
      return;
    }

    const loadMoreButton = page.getByRole('button', { name: 'Load more' });
    if (!await loadMoreButton.isVisible().catch(() => false)) {
      return;
    }

    await loadMoreButton.click({ force: true });
    await page.waitForTimeout(1000);
  }
}

async function ensureAccountExists(page: Page): Promise<string> {
  logStep(`ensureAccountExists:start account=${testAccountName}`);
  await openAccountsView(page);
  const accountRow = page.getByRole('row').filter({ hasText: testAccountName }).first();
  const createDialog = page.locator('[test-id="create-resource-dialog"]');

  await ensureListRowVisible(page, accountRow);

  if (!await accountRow.isVisible().catch(() => false)) {
    logStep(`ensureAccountExists:create account=${testAccountName}`);
    await page.locator('[test-id="generic-list-view-create-button"]').click();
    await createDialog.waitFor({ state: 'visible', timeout: 10000 });
    await page.locator('[test-id="create-field-metadata_name"]').click();
    await page.locator('[test-id="create-field-spec_type"]').click();
    await page.locator('[test-id="create-field-spec_type-option-account"]').click();
    await page.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(testAccountName);
    const submitButton = page.locator('[test-id="create-resource-submit"]');
    const alreadyExistsAlert = page.getByText(`accounts.core.platform-mesh.io "${testAccountName}" already exists`);
    const transientWebhookAlert = page.getByText(/failed calling webhook|connection refused|Internal error occurred/i);

    for (let attempt = 0; attempt < 4; attempt++) {
      await submitButton.click();

      const outcome = await Promise.race([
        alreadyExistsAlert.waitFor({ state: 'visible', timeout: 30000 }).then(() => 'exists'),
        transientWebhookAlert.waitFor({ state: 'visible', timeout: 30000 }).then(() => 'retry'),
        createDialog.waitFor({ state: 'hidden', timeout: 30000 }).then(() => 'submitted'),
      ]);

      if (outcome === 'submitted' || outcome === 'exists') {
        break;
      }

      if (attempt === 3) {
        throw new Error('Account creation kept failing due to transient webhook errors');
      }

      const alertCloseButton = page.getByRole('button', { name: 'Close' }).first();
      if (await alertCloseButton.isVisible().catch(() => false)) {
        await alertCloseButton.click();
      }
      await page.waitForTimeout(10000);
    }
  }

  if (await createDialog.isVisible().catch(() => false)) {
    const dialogCancelButton = createDialog.getByRole('button', { name: 'Cancel' });
    const dialogCloseButton = createDialog.getByRole('button', { name: 'Close' });

    if (await dialogCancelButton.isVisible().catch(() => false)) {
      await dialogCancelButton.click();
    } else if (await dialogCloseButton.isVisible().catch(() => false)) {
      await dialogCloseButton.click();
    } else {
      await page.keyboard.press('Escape').catch(() => {});
    }

    await createDialog.waitFor({ state: 'hidden', timeout: 10000 }).catch(() => {});
  }

  const alertCloseButton = page.getByRole('button', { name: 'Close' }).first();
  if (await alertCloseButton.isVisible().catch(() => false)) {
    await alertCloseButton.click();
  }

  waitForAccountExists();
  logStep(`ensureAccountExists:wait-ready account=${testAccountName}`);
  waitForAccountReady();
  const accountUrl = `https://${newOrgName}.portal.localhost:8443/home/accounts/${testAccountName}/dashboard`;
  logStep(`ensureAccountExists:navigate-direct account=${testAccountName} url=${accountUrl}`);
  await page.goto(accountUrl, { waitUntil: 'domcontentloaded' });
  await expect(page.locator('[test-id="generic-detail-view-download"]')).toBeVisible({ timeout: 30000 });
  logStep(`ensureAccountExists:done account=${testAccountName}`);
  return accountUrl;
}

async function downloadAccountKubeconfig(page: Page): Promise<string> {
  const downloadButton = page.locator('[test-id="generic-detail-view-download"]');
  let download = null;

  for (let attempt = 0; attempt < 2; attempt++) {
    const downloadPromise = page.waitForEvent('download', { timeout: 10000 }).catch(() => null);
    await downloadButton.click();
    download = await downloadPromise;
    if (download) {
      break;
    }

    const closeButton = page.locator('ui5-message-strip-alert button, [ref="e6"]');
    if (await closeButton.isVisible().catch(() => false)) {
      await closeButton.click();
    }
    await page.waitForTimeout(5000);
  }

  expect(download).toBeDefined();

  const targetDir = path.join(tmpdir(), 'platform-mesh-e2e');
  if (!existsSync(targetDir)) {
    mkdirSync(targetDir, { recursive: true });
  }

  const kubeconfigPath = path.join(targetDir, `${testAccountName}-oidc.kubeconfig`);
  await download!.saveAs(kubeconfigPath);
  normalizeDownloadedKubeconfig(kubeconfigPath);
  return kubeconfigPath;
}

async function deleteAccount(page: Page, accountUrl: string): Promise<void> {
  logStep(`deleteAccount:start url=${accountUrl}`);
  waitForAccountReady();
  await page.goto(accountUrl, { waitUntil: 'domcontentloaded' });

  for (let attempt = 0; attempt < 3; attempt++) {
    const downloadButton = page.locator('[test-id="generic-detail-view-download"]');
    if (await downloadButton.isVisible().catch(() => false)) {
      break;
    }

    if (attempt === 2) {
      throw new Error(`Account dashboard did not become ready before deletion, final URL=${page.url()}`);
    }

    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);
  }

  const deleteSelectors = [
    '[test-id="generic-detail-view-delete"]',
    '[test-id="delete-resource-button"]',
    'button:has-text("Delete")',
    '[role="button"][aria-label="Delete"]',
  ];

  let clickedDelete = false;
  for (const selector of deleteSelectors) {
    const locator = page.locator(selector).first();
    if (await locator.isVisible().catch(() => false)) {
      logStep(`deleteAccount:clicked-delete-selector selector=${selector}`);
      await clickRobust(locator);
      clickedDelete = true;
      break;
    }
  }

  if (!clickedDelete) {
    const overflowButtons = [
      page.getByRole('button', { name: 'Additional Options' }).last(),
      page.locator('[aria-label="Additional Options"]').last(),
    ];

    for (const overflowButton of overflowButtons) {
      if (await overflowButton.isVisible().catch(() => false)) {
        logStep('deleteAccount:open-additional-options');
        await clickRobust(overflowButton);
        break;
      }
    }

    const overflowDeleteOptions = [
      page.getByRole('menuitem', { name: /delete/i }).last(),
      page.getByRole('button', { name: /delete/i }).last(),
      page.locator('[aria-label="Delete"]').last(),
      page.getByText('Delete', { exact: true }).last(),
    ];

    for (const overflowDeleteOption of overflowDeleteOptions) {
      if (await overflowDeleteOption.isVisible().catch(() => false)) {
        logStep('deleteAccount:clicked-delete-from-overflow');
        await clickRobust(overflowDeleteOption);
        clickedDelete = true;
        break;
      }
    }
  }

  if (!clickedDelete) {
    const visibleButtons = await page.locator('button').evaluateAll((nodes) => nodes
      .map((node) => ({
        text: (node.textContent || '').trim(),
        ariaLabel: node.getAttribute('aria-label') || '',
        title: node.getAttribute('title') || '',
      }))
      .filter((entry) => entry.text || entry.ariaLabel || entry.title));
    throw new Error(`Could not find account delete button on the account detail page, buttons=${JSON.stringify(visibleButtons)}`);
  }

  const confirmButtons = [
    page.getByRole('button', { name: 'Submit', exact: true }).last(),
    page.getByRole('button', { name: 'Confirm', exact: true }).last(),
    page.getByRole('button', { name: 'Delete', exact: true }).last(),
    page.getByRole('button', { name: /submit/i }).last(),
    page.getByRole('button', { name: /delete/i }).last(),
    page.getByRole('button', { name: /remove/i }).last(),
    page.locator('[test-id="delete-resource-confirm"]').first(),
  ];

  const confirmInputSelectors = [
    'input[placeholder="Type name"]',
    '[test-id="delete-resource-name-confirmation"] input',
    '[test-id="delete-resource-confirmation-input"] input',
    'input',
  ];

  for (const selector of confirmInputSelectors) {
    const input = page.locator(selector).last();
    if (await input.isVisible().catch(() => false)) {
      await input.fill(testAccountName);
      logStep(`deleteAccount:typed-confirmation selector=${selector}`);
      break;
    }
  }

  const visibleDialogText = await page.locator('body').innerText().catch(() => '');
  logStep(`deleteAccount:confirm-body=${JSON.stringify(visibleDialogText.slice(0, 500))}`);

  const visibleButtons = await page.locator('button').evaluateAll((nodes) => nodes
    .map((node) => ({
      text: (node.textContent || '').trim(),
      ariaLabel: node.getAttribute('aria-label') || '',
      title: node.getAttribute('title') || '',
    }))
    .filter((entry) => entry.text || entry.ariaLabel || entry.title));
  logStep(`deleteAccount:buttons=${JSON.stringify(visibleButtons)}`);

  let confirmedDelete = false;
  for (let index = 0; index < confirmButtons.length; index++) {
    const button = confirmButtons[index];
    if (await button.isVisible().catch(() => false)) {
      logStep(`deleteAccount:clicked-confirm index=${index}`);
      await clickRobust(button);
      confirmedDelete = true;
      break;
    }
  }

  if (!confirmedDelete) {
    throw new Error(`Could not find account delete confirmation button, buttons=${JSON.stringify(visibleButtons)}`);
  }

  waitForAccountDeleted();
  await openAccountsView(page);
  const accountRow = page.getByRole('row').filter({ hasText: testAccountName }).first();
  await expect(accountRow).not.toBeVisible({ timeout: 30000 });
  logStep(`deleteAccount:done url=${accountUrl}`);
}

export { deleteAccount, downloadAccountKubeconfig, ensureAccountExists };
