import { expect, Locator, Page } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';

import { defaultHttpBinName, exampleDataOverlayPath, httpbinProviderManifestPath, infraKubeconfigPath, newOrgName, testNamespaceHttpBinName, testNamespaceName } from './constants';
import { logStep } from './log';
import { runAdminKubectl, runInfraKubectl, runRuntimeKubectl } from './runtime';

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

function isArgoCD(): boolean {
  if (!existsSync(infraKubeconfigPath)) {
    return false;
  }
  try {
    runInfraKubectl(['get', 'namespace', 'argocd']);
    return true;
  } catch {
    return false;
  }
}

function waitForArgoApplication(name: string, namespace: string, timeoutSeconds: number): void {
  const deadline = Date.now() + timeoutSeconds * 1000;
  while (Date.now() < deadline) {
    try {
      const health = runInfraKubectl(['get', 'application', name, '-n', namespace, '-o', 'jsonpath={.status.health.status}']);
      const sync = runInfraKubectl(['get', 'application', name, '-n', namespace, '-o', 'jsonpath={.status.sync.status}']);
      if (health === 'Healthy' && sync === 'Synced') {
        return;
      }
    } catch {
      // resource may not exist yet
    }
    execFileSync('sleep', ['2']);
  }
  throw new Error(`Timed out waiting for ArgoCD Application ${namespace}/${name} to become Healthy and Synced`);
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

  if (isArgoCD()) {
    waitForArgoApplication('api-syncagent', 'argocd', 120);
    waitForArgoApplication('example-httpbin-provider', 'argocd', 120);
  } else {
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
  await scopeCombobox.click();
  await scopeCombobox.press('F4');

  const namespaceItem = page.locator(`[data-testid="namespace-selection-combobox-item-${namespaceName}"]`).or(
    page.getByRole('option', { name: namespaceName, exact: true }),
  ).first();
  await namespaceItem.waitFor({ state: 'visible', timeout: 10000 });
  await namespaceItem.click();
  await expect(scopeCombobox).toContainText(namespaceName);
}

async function ensureHttpBinExists(page: Page, namespaceName: string, httpBinName: string): Promise<void> {
  logStep(`ensureHttpBinExists:start namespace=${namespaceName} name=${httpBinName}`);
  await openHttpBinsView(page);
  await selectNamespaceScope(page, namespaceName);

  const httpBinRow = page.getByRole('row').filter({ hasText: httpBinName }).first();
  if (!await httpBinRow.isVisible().catch(() => false)) {
    await page.getByRole('button', { name: 'Create' }).click();
    await page.locator('[test-id="create-resource-dialog"]').waitFor({ state: 'visible', timeout: 10000 });
    await page.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(httpBinName);

    // Select namespace from dropdown
    const namespaceDropdown = page.locator('[test-id="pm-dynamic-select-v1.Namespaces.items"]');
    await namespaceDropdown.waitFor({ state: 'visible', timeout: 10000 });
    await namespaceDropdown.click();

    const namespaceOption = page.locator(`[test-id="pm-dynamic-select-v1.Namespaces.items-option-${namespaceName}"]`);
    await namespaceOption.waitFor({ state: 'visible', timeout: 10000 });
    await namespaceOption.click();

    // Wait for submit button to be enabled after namespace selection
    const submitButton = page.locator('[test-id="create-resource-submit"]');
    await expect(submitButton).toBeEnabled({ timeout: 10000 });
    await clickRobust(submitButton);
    await page.locator('[test-id="create-resource-dialog"]').waitFor({ state: 'hidden', timeout: 60000 });
  }

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
