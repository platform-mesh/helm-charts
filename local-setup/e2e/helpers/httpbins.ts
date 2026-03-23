import { expect, Locator, Page } from '@playwright/test';

import { defaultHttpBinName, exampleDataOverlayPath, httpbinProviderManifestPath, newOrgName, testAccountName, testNamespaceHttpBinName, testNamespaceName } from './constants';
import { logStep } from './log';
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

  for (let attempt = 0; attempt < 12; attempt++) {
    await page.goto(`https://${newOrgName}.portal.localhost:8443/home`, { waitUntil: 'domcontentloaded' });
    await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});
    const navItem = page.locator('[data-testid="orchestrate_platform-mesh_io_httpbins_httpbins"]');
    if (await navItem.isVisible().catch(() => false)) {
      return;
    }
    await page.waitForTimeout(10000);
  }

  throw new Error('HTTPBin navigation item did not appear after bootstrapping example data');
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
  await page.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(namespaceName);
  await page.locator('[test-id="create-resource-submit"]').click();
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
  if (!await page.locator('[data-testid="orchestrate_platform-mesh_io_httpbins_httpbins"]').isVisible().catch(() => false)) {
    await ensureExampleHttpbinProvider(page);
  }
  await page.locator('[data-testid="orchestrate_platform-mesh_io_httpbins_httpbins"]').click();

  const httpBinsReadyLocators = [
    page.locator('[data-testid="namespace-selection-combobox"]').first(),
    page.getByRole('button', { name: 'Create' }).first(),
    page.getByRole('heading', { name: 'HttpBins', exact: true }),
  ];

  await Promise.any(httpBinsReadyLocators.map((locator) => locator.waitFor({ state: 'visible', timeout: 15000 })));
}

async function selectNamespaceScope(page: Page, namespaceName: string): Promise<void> {
  const scopeCombobox = page.locator('[data-testid="namespace-selection-combobox"]').first();
  await expect(scopeCombobox).toBeVisible({ timeout: 15000 });
  if ((await scopeCombobox.textContent().catch(() => ''))?.includes(namespaceName)) {
    return;
  }

  for (let attempt = 0; attempt < 3; attempt++) {
    await scopeCombobox.click();
    await scopeCombobox.press('F4').catch(() => {});
    await page.waitForTimeout(500);

    const namespaceItem = page.locator(`[data-testid="namespace-selection-combobox-item-${namespaceName}"]`).or(
      page.getByRole('option', { name: namespaceName, exact: true }),
    ).first();

    if (await namespaceItem.isVisible().catch(() => false)) {
      await namespaceItem.click();
      await expect(scopeCombobox).toContainText(namespaceName);
      return;
    }

    const comboInput = scopeCombobox.locator('input').first();
    if (await comboInput.isVisible().catch(() => false)) {
      await comboInput.click();
      await comboInput.fill(namespaceName);
      await comboInput.press('Enter');
      if ((await scopeCombobox.textContent().catch(() => ''))?.includes(namespaceName)) {
        return;
      }
    }

    await page.keyboard.press('Escape').catch(() => {});
    await page.waitForTimeout(1000);
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
      await page.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(httpBinName);
      await page.locator('[test-id="pm-dynamic-select-v1.Namespaces.items"]').click();

      const namespaceOption = page.locator(`[test-id="pm-dynamic-select-v1.Namespaces.items-option-${namespaceName}"]`).or(
        page.getByRole('option', { name: namespaceName, exact: true }),
      ).first();
      await namespaceOption.waitFor({ state: 'visible', timeout: 10000 });
      await namespaceOption.click();

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
