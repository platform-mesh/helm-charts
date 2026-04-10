import { expect, Locator, Page } from '@playwright/test';

import { defaultHttpBinName, exampleDataOverlayPath, httpbinProviderManifestPath, newOrgName, testAccountName, testNamespaceHttpBinName, testNamespaceName } from './constants';
import { logStep, portalOrgUrl } from './log';
import { runAdminKubectl, runRuntimeKubectl } from './runtime';

async function clickRobust(locator: Locator): Promise<void> {
  try {
    await locator.click({ force: true, timeout: 5000 });
    return;
  } catch {
    await locator.evaluate((node) => {
      (node as HTMLElement).click();
    });
  }
}

async function clickFirstVisible(page: Page, selectors: string[]): Promise<void> {
  for (const selector of selectors) {
    const locator = page.locator(selector).first();
    if (await locator.isVisible().catch(() => false)) {
      await locator.click();
      return;
    }
  }

  throw new Error(`None of the selectors were visible: ${selectors.join(', ')}`);
}

async function closeDialogIfVisible(dialog: Locator): Promise<void> {
  if (!await dialog.isVisible().catch(() => false)) {
    return;
  }

  const cancelButton = dialog.getByRole('button', { name: 'Cancel' });
  const closeButton = dialog.getByRole('button', { name: 'Close' });

  if (await cancelButton.isVisible().catch(() => false)) {
    await clickRobust(cancelButton);
  } else if (await closeButton.isVisible().catch(() => false)) {
    await clickRobust(closeButton);
  }

  await dialog.waitFor({ state: 'hidden', timeout: 10000 }).catch(() => {});
}

function ensureExampleHttpbinProviderWorkspace(): void {
  runRuntimeKubectl(['apply', '-k', exampleDataOverlayPath]);

  runAdminKubectl([
    'create-workspace',
    'providers',
    '--type=root:providers',
    '--ignore-existing',
    '--server',
    'https://localhost:8443/clusters/root',
  ]);

  runAdminKubectl([
    'create-workspace',
    'httpbin-provider',
    '--type=root:provider',
    '--ignore-existing',
    '--server',
    'https://localhost:8443/clusters/root:providers',
  ]);

  runAdminKubectl([
    'apply',
    '-k',
    httpbinProviderManifestPath,
    '--server',
    'https://localhost:8443/clusters/root:providers:httpbin-provider',
  ]);

  runRuntimeKubectl([
    'wait',
    '--namespace',
    'default',
    '--for=condition=Ready',
    'helmreleases',
    '--timeout=120s',
    'api-syncagent',
  ]);

  runRuntimeKubectl([
    'wait',
    '--namespace',
    'default',
    '--for=condition=Ready',
    'helmreleases',
    '--timeout=120s',
    'example-httpbin-provider',
  ]);
}

function ensureHttpBinExistsViaBackend(namespaceName: string, httpBinName: string): void {
  const manifest = [
    'apiVersion: orchestrate.platform-mesh.io/v1alpha1',
    'kind: HttpBin',
    'metadata:',
    `  name: ${httpBinName}`,
    `  namespace: ${namespaceName}`,
    '',
  ].join('\n');

  runAdminKubectl([
    'apply',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}:${testAccountName}`,
    '-f',
    '-',
  ], manifest);

  runAdminKubectl([
    'wait',
    '--server',
    `https://localhost:8443/clusters/root:orgs:${newOrgName}:${testAccountName}`,
    '--for=condition=Ready',
    '--timeout=120s',
    '-n',
    namespaceName,
    `httpbins.orchestrate.platform-mesh.io/${httpBinName}`,
  ]);
}

async function ensureExampleHttpbinProvider(page: Page): Promise<void> {
  ensureExampleHttpbinProviderWorkspace();
  await page.goto(portalOrgUrl(`/home/accounts/${testAccountName}/orchestrate_platform-mesh_io_httpbins`), { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});
}

async function openNamespacesView(page: Page): Promise<void> {
  await clickFirstVisible(page, [
    '[data-testid="core_namespaces_namespaces"]',
    '[data-testid="namespaces_namespaces"]',
    '[data-testid="namespace_namespaces"]',
    'a:has-text("Namespaces")',
    '[role="link"]:has-text("Namespaces")',
  ]);

  const namespacesReadyLocators = [
    page.locator('[test-id="generic-list-view-create-button"]'),
    page.getByRole('heading', { name: 'Namespaces', exact: true }),
    page.getByText('Namespaces', { exact: true }),
  ];

  await Promise.any(namespacesReadyLocators.map((locator) => locator.waitFor({ state: 'visible', timeout: 15000 })));
}

async function ensureNamespaceExists(page: Page, namespaceName: string): Promise<void> {
  logStep(`ensureNamespaceExists:start namespace=${namespaceName}`);
  await openNamespacesView(page);
  const namespaceRow = page.getByText(namespaceName, { exact: true }).first();
  const createDialog = page.locator('[test-id="create-resource-dialog"]');

  if (await namespaceRow.isVisible().catch(() => false)) {
    return;
  }

  await page.locator('[test-id="generic-list-view-create-button"]').click();
  await createDialog.waitFor({ state: 'visible', timeout: 10000 });
  const nameInput = page.getByRole('textbox').first();
  await nameInput.waitFor({ state: 'visible', timeout: 5000 });
  await nameInput.click({ force: true });
  await page.keyboard.type(namespaceName, { delay: 30 });
  await page.locator('[test-id="create-resource-submit"]').click({ force: true });
  const alreadyExistsAlert = page.getByText(`namespaces \"${namespaceName}\" already exists`);
  await Promise.race([
    expect(namespaceRow).toBeVisible({ timeout: 30000 }),
    alreadyExistsAlert.waitFor({ state: 'visible', timeout: 30000 }),
  ]);

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

  await expect(page.getByText(namespaceName, { exact: true }).first()).toBeVisible({ timeout: 30000 });
  logStep(`ensureNamespaceExists:done namespace=${namespaceName}`);
}

async function openHttpBinsView(page: Page): Promise<void> {
  await ensureExampleHttpbinProvider(page);

  const httpBinsReadyLocators = [
    page.locator('ui5-select').first(),
    page.getByRole('button', { name: 'Create' }).first(),
    page.getByRole('heading', { name: 'HttpBins', exact: true }),
  ];

  await Promise.any(httpBinsReadyLocators.map((locator) => locator.waitFor({ state: 'visible', timeout: 15000 })));
}

async function selectNamespaceScope(page: Page, namespaceName: string): Promise<void> {
  logStep(`selectNamespaceScope:start namespace=${namespaceName}`);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'debug-namespace-scope.png', fullPage: true });

  // Dump all ui5-select elements for debugging
  const ui5SelectCount = await page.locator('ui5-select').count();
  for (let i = 0; i < ui5SelectCount; i++) {
    const text = await page.locator('ui5-select').nth(i).textContent().catch(() => '');
    logStep(`selectNamespaceScope:ui5-select[${i}] text="${text?.trim()}"`);
  }

  // The namespace scope dropdown shows "-all-" and contains namespace names
  // Find it by looking for the one with "-all-" text
  let scopeSelect = null;
  for (let i = 0; i < ui5SelectCount; i++) {
    const text = await page.locator('ui5-select').nth(i).textContent().catch(() => '');
    if (text?.includes('-all-') || text?.includes(namespaceName)) {
      scopeSelect = page.locator('ui5-select').nth(i);
      logStep(`selectNamespaceScope:found-scope-select index=${i}`);
      break;
    }
  }

  if (!scopeSelect) {
    logStep(`selectNamespaceScope:no-scope-select-found ui5SelectCount=${ui5SelectCount}`);
    // If namespace is "default" and we're on -all- scope, it's already included
    if (namespaceName === 'default') {
      logStep('selectNamespaceScope:default-namespace-skip');
      return;
    }
    throw new Error(`Namespace scope dropdown not found for ${namespaceName}`);
  }

  if ((await scopeSelect.textContent().catch(() => ''))?.includes(namespaceName)) {
    return;
  }

  await scopeSelect.click({ force: true });
  await page.waitForTimeout(500);

  const namespaceItem = page.getByRole('option', { name: namespaceName, exact: true }).first();
  if (await namespaceItem.isVisible().catch(() => false)) {
    await namespaceItem.click();
    return;
  }

  const ui5Option = page.locator('ui5-option').filter({ hasText: namespaceName }).first();
  if (await ui5Option.isVisible().catch(() => false)) {
    await ui5Option.click({ force: true });
    return;
  }

  await page.keyboard.press('Escape').catch(() => {});
  // If on "-all-" and selecting "default", skip — it's already included
  if (namespaceName === 'default') {
    logStep('selectNamespaceScope:default-namespace-fallback-skip');
    return;
  }
  throw new Error(`Unable to select namespace scope ${namespaceName}`);
}

async function ensureHttpBinExists(page: Page, namespaceName: string, httpBinName: string): Promise<void> {
  logStep(`ensureHttpBinExists:start namespace=${namespaceName} name=${httpBinName}`);
  for (let attempt = 0; attempt < 2; attempt++) {
    await openHttpBinsView(page);
    await selectNamespaceScope(page, namespaceName);

    const httpBinRow = page.getByRole('row').filter({ hasText: httpBinName }).first();
    if (!await httpBinRow.isVisible().catch(() => false)) {
      const createDialog = page.locator('[test-id="create-resource-dialog"]');
      await page.getByRole('button', { name: 'Create' }).click();
      await createDialog.waitFor({ state: 'visible', timeout: 10000 });
      const httpBinNameInput = page.getByRole('textbox').first();
      await httpBinNameInput.waitFor({ state: 'visible', timeout: 5000 });
      await httpBinNameInput.click({ force: true });
      await page.keyboard.type(httpBinName, { delay: 30 });

      // Select namespace from the dropdown in the create dialog
      // The form has multiple ui5-selects; the namespace one is after the first (items-per-load)
      const dialogSelects = page.locator('ui5-select');
      const selectCount = await dialogSelects.count();
      for (let i = 0; i < selectCount; i++) {
        const text = await dialogSelects.nth(i).textContent().catch(() => '');
        if (text?.includes(namespaceName) || text?.includes('-all-') || text === '') {
          await dialogSelects.nth(i).scrollIntoViewIfNeeded();
          await dialogSelects.nth(i).click({ force: true, timeout: 3000 });
          await page.waitForTimeout(500);
          const nsOpt = page.locator('ui5-option').filter({ hasText: namespaceName }).first();
          if (await nsOpt.isVisible().catch(() => false)) {
            await nsOpt.click({ force: true });
            logStep(`ensureHttpBinExists:namespace-selected=${namespaceName}`);
          } else {
            await page.keyboard.press('Escape').catch(() => {});
          }
          break;
        }
      }

      const submitButton = page.locator('[test-id="create-resource-submit"]');
      await expect(submitButton).toBeEnabled({ timeout: 10000 });
      await submitButton.click();

      await Promise.race([
        createDialog.waitFor({ state: 'hidden', timeout: 30000 }),
        expect(httpBinRow).toBeVisible({ timeout: 30000 }),
      ]).catch(async () => {
        await closeDialogIfVisible(createDialog);
      });

      if (await createDialog.isVisible().catch(() => false)) {
        await closeDialogIfVisible(createDialog);
      }
    }

    if (await httpBinRow.isVisible().catch(() => false)) {
      const readyIcon = httpBinRow.locator('[test-id="value-cell-status.ready-boolean"]').first();
      await expect(readyIcon).toBeVisible({ timeout: 80000 });
      logStep(`ensureHttpBinExists:done namespace=${namespaceName} name=${httpBinName}`);
      return;
    }

    logStep(`ensureHttpBinExists:retry namespace=${namespaceName} name=${httpBinName} attempt=${attempt + 1}`);
    await page.reload({ waitUntil: 'domcontentloaded' }).catch(() => {});
    await page.waitForTimeout(3000);
  }

  ensureHttpBinExistsViaBackend(namespaceName, httpBinName);
  await openHttpBinsView(page);
  await selectNamespaceScope(page, namespaceName);
  const nameCell = page.getByRole('row').filter({ hasText: httpBinName }).first();
  await expect(nameCell).toBeVisible({ timeout: 30000 });
  const readyIcon = nameCell.locator('[test-id="value-cell-status.ready-boolean"]').first();
  await expect(readyIcon).toBeVisible({ timeout: 80000 });
  logStep(`ensureHttpBinExists:done namespace=${namespaceName} name=${httpBinName}`);
}

async function assertHttpBinLinkWorks(page: Page, namespaceName: string, httpBinName: string): Promise<void> {
  logStep(`assertHttpBinLinkWorks:start namespace=${namespaceName} name=${httpBinName}`);
  await openHttpBinsView(page);
  await selectNamespaceScope(page, namespaceName);

  const row = page.getByRole('row').filter({ hasText: httpBinName }).first();
  await expect(row).toBeVisible({ timeout: 30000 });
  const link = row.locator('a[href^="http"]').first();
  await expect(link).toBeVisible({ timeout: 10000 });
  const href = await link.getAttribute('href');
  expect(href).toBeTruthy();

  const httpBinPage = await page.context().newPage();
  await httpBinPage.goto(href!, { waitUntil: 'domcontentloaded' });
  await expect(httpBinPage.locator('body')).toContainText(/httpbin/i, { timeout: 15000 });
  await httpBinPage.close();
  logStep(`assertHttpBinLinkWorks:done namespace=${namespaceName} name=${httpBinName}`);
}

export {
  assertHttpBinLinkWorks,
  clickRobust, defaultHttpBinName, ensureExampleHttpbinProviderWorkspace,
  ensureHttpBinExists,
  ensureNamespaceExists,
  openHttpBinsView,
  selectNamespaceScope, testNamespaceHttpBinName,
  testNamespaceName
};
