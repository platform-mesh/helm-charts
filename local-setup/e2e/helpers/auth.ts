import { expect, Page } from '@playwright/test';

import { newOrgName, orgReadyTimeoutSeconds, portalBaseUrl, type TestUser } from './constants';
import { logStep } from './log';

async function loginUser(page: Page, user: TestUser): Promise<void> {
  await page.getByRole('textbox', { name: 'Email' }).fill(user.email);
  await page.getByRole('textbox', { name: 'Password' }).fill(user.password);
  await page.getByRole('button', { name: 'Sign In' }).click();
}

async function loginToInitialKeycloak(page: Page, user: TestUser): Promise<void> {
  await page.getByRole('textbox', { name: 'Email' }).fill(user.email);
  await page.getByRole('textbox', { name: 'Password' }).fill(user.keycloakPassword);
  await page.getByRole('button', { name: 'Sign In' }).click();

  const loginHeading = page.getByRole('heading', { name: 'Sign in to your account' });
  if (await loginHeading.isVisible().catch(() => false)) {
    await page.getByRole('textbox', { name: 'Email' }).fill(user.email);
    await page.getByRole('textbox', { name: 'Password' }).fill(user.password);
    await page.getByRole('button', { name: 'Sign In' }).click();
  }
}

async function registerOrLoginUser(page: Page, user: TestUser): Promise<void> {
  await page.click('text=Register', { timeout: 5000 });
  await page.fill('input[name="email"]', user.email);
  await page.fill('input[id="password"]', user.password);
  await page.fill('input[id="password-confirm"]', user.password);
  await page.fill('input[id="firstName"]', user.firstName);
  await page.fill('input[id="lastName"]', user.lastName);

  await page.click('input[value="Register"]', { timeout: 5000 });

  const emailExistsError = page.getByText('Email already exists.');
  const welcomeText = page.getByText('Welcome to the Platform Mesh Portal!');

  const result = await Promise.race([
    welcomeText.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'success'),
    emailExistsError.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'exists'),
  ]).catch(() => 'timeout');

  if (result === 'exists') {
    await page.getByRole('link', { name: 'Back to Login' }).click();
    await loginUser(page, user);
  }
}

async function completeAccountSetup(page: Page, user: TestUser): Promise<void> {
  const proceedLink = page.getByRole('link', { name: 'Click here to proceed' });
  const newPasswordField = page.getByRole('textbox', { name: 'New Password' });

  const firstElement = await Promise.race([
    proceedLink.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'proceed'),
    newPasswordField.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'password'),
  ]).catch(() => 'none');

  if (firstElement === 'proceed') {
    await proceedLink.click();
    await newPasswordField.waitFor({ state: 'visible', timeout: 5000 });
  }

  if (firstElement === 'proceed' || firstElement === 'password') {
    await newPasswordField.fill(user.password);
    await page.getByRole('textbox', { name: 'Confirm password' }).fill(user.password);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  const firstNameField = page.getByRole('textbox', { name: 'First name' });
  const backToAppLink = page.getByRole('link', { name: 'Back to Application' });

  const nextElement = await Promise.race([
    firstNameField.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'name'),
    backToAppLink.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'back'),
  ]).catch(() => 'none');

  if (nextElement === 'name') {
    await firstNameField.fill(user.firstName);
    await page.getByRole('textbox', { name: 'Last name' }).fill(user.lastName);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  const backLink = page.getByRole('link', { name: 'Back to Application' });
  if (await backLink.isVisible().catch(() => false)) {
    await backLink.click();
  }

  const emailField = page.getByRole('textbox', { name: 'Email' });
  if (await emailField.isVisible().catch(() => false)) {
    await emailField.fill(user.email);
    await page.getByRole('textbox', { name: 'Password' }).fill(user.password);
    await page.getByRole('button', { name: 'Sign In' }).click();
  }
}

async function waitForAuthUsableState(page: Page): Promise<void> {
  for (let attempt = 0; attempt < 3; attempt++) {
    const registerLink = page.getByText('Register', { exact: true });
    const loginEmail = page.getByRole('textbox', { name: 'Email' });
    const welcomeText = page.getByText('Welcome to the Platform Mesh Portal!');

    const state = await Promise.race([
      registerLink.waitFor({ state: 'visible', timeout: 10000 }).then(() => 'register'),
      loginEmail.waitFor({ state: 'visible', timeout: 10000 }).then(() => 'login'),
      welcomeText.waitFor({ state: 'visible', timeout: 10000 }).then(() => 'welcome'),
    ]).catch(() => 'retry');

    if (state !== 'retry') {
      break;
    }

    if (attempt === 2) {
      throw new Error('Portal landing page did not reach a usable auth state');
    }

    await page.reload({ waitUntil: 'domcontentloaded' });
  }
}

async function gotoWithRetry(page: Page, url: string): Promise<void> {
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      await page.goto(url, { waitUntil: 'load', timeout: 15000 });
      return;
    } catch (error) {
      if (attempt === 4) {
        throw error;
      }
      await page.waitForTimeout(5000);
    }
  }
}

async function fillOrganizationField(page: Page, value: string): Promise<void> {
  const host = page
    .locator('[test-id="organization-management-onboard-input"]')
    .or(page.locator('ui5-input[placeholder="Enter organization name"]'))
    .first();
  const nativeInput = host.locator('input').first();
  logStep(`fillOrganizationField:start value=${value}`);

  if (await nativeInput.isVisible().catch(() => false)) {
    logStep('fillOrganizationField:using-native-input');
    await nativeInput.click();
    await nativeInput.fill(value);
    await expect(nativeInput).toHaveValue(value, { timeout: 5000 });
    logStep('fillOrganizationField:native-input-filled');
    return;
  }

  logStep('fillOrganizationField:using-ui5-host');
  await host.click();
  await page.keyboard.press('Meta+A').catch(() => {});
  await page.keyboard.press('Control+A').catch(() => {});
  await page.keyboard.press('Backspace').catch(() => {});
  await page.keyboard.type(value, { delay: 100 });

  const typedValue = await host.evaluate((element) => (element as HTMLElement & { value?: string }).value ?? '');
  logStep(`fillOrganizationField:typed-value=${typedValue}`);
  if (typedValue === value) {
    logStep('fillOrganizationField:keyboard-typing-worked');
    return;
  }

  await host.evaluate((element, nextValue) => {
    const ui5Input = element as HTMLElement & { value?: string };
    ui5Input.value = nextValue;
    ui5Input.setAttribute('value', nextValue);
    ui5Input.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, data: nextValue, inputType: 'insertText' }));
    ui5Input.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
  }, value);
  await expect.poll(
    async () => await host.evaluate((element) => (element as HTMLElement & { value?: string }).value ?? ''),
    { timeout: 5000 },
  ).toBe(value);
  logStep('fillOrganizationField:ui5-host-filled');
}

async function fillSwitchOrganizationField(page: Page, value: string): Promise<void> {
  const host = page
    .locator('[test-id="organization-management-input"]')
    .or(page.locator('ui5-combobox'))
    .first();
  const nativeInput = host.locator('input').first();
  logStep(`fillSwitchOrganizationField:start value=${value}`);

  if (await nativeInput.isVisible().catch(() => false)) {
    logStep('fillSwitchOrganizationField:using-native-input');
    await nativeInput.click();
    await nativeInput.fill(value);
    await expect(nativeInput).toHaveValue(value, { timeout: 5000 });
    return;
  }

  logStep('fillSwitchOrganizationField:using-host-keyboard');
  await host.click();
  await page.keyboard.press('Meta+A').catch(() => {});
  await page.keyboard.press('Control+A').catch(() => {});
  await page.keyboard.press('Backspace').catch(() => {});
  await page.keyboard.type(value, { delay: 100 });
}

async function ensureWelcomePage(page: Page, user: TestUser): Promise<void> {
  await gotoWithRetry(page, portalBaseUrl);
  await page.waitForLoadState('domcontentloaded', { timeout: 10000 }).catch(() => {});

  await waitForAuthUsableState(page);

  await registerOrLoginUser(page, user);

  for (let attempt = 0; attempt < 4; attempt++) {
    await page.waitForURL(`${portalBaseUrl}**`, { timeout: 10000 }).catch(() => {});
    await page.waitForLoadState('load', { timeout: 10000 }).catch(() => {});

    const landingState = await Promise.race([
      page.getByText('Welcome to the Platform Mesh Portal!').waitFor({ state: 'visible', timeout: 5000 }).then(() => 'welcome'),
      page.locator('[test-id="organization-management-input"]').waitFor({ state: 'visible', timeout: 5000 }).then(() => 'org-management'),
      page.getByText("Welcome! Let's get started.", { exact: true }).waitFor({ state: 'visible', timeout: 5000 }).then(() => 'home'),
    ]).catch(() => 'retry');

    if (landingState !== 'retry') {
      return;
    }

    if (attempt === 3) {
      throw new Error(`Portal welcome page did not reach a usable post-login state, final URL=${page.url()}`);
    }

    await page.reload({ waitUntil: 'domcontentloaded' }).catch(() => {});
  }
}

async function ensurePortalHome(page: Page, user?: TestUser): Promise<void> {
  const welcome = page.getByText("Welcome! Let's get started.", { exact: true });
  const orgPortalBaseUrl = `https://${newOrgName}.portal.localhost:8443/`;

  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      logStep(`ensurePortalHome:attempt=${attempt + 1} url=${page.url()}`);
      if (!page.url().startsWith(orgPortalBaseUrl)) {
        await gotoWithRetry(page, `${orgPortalBaseUrl}home`);
      }
      await page.waitForLoadState('networkidle', { timeout: 15000 });
      await expect(welcome).toBeVisible({ timeout: 5000 });
      logStep(`ensurePortalHome:done url=${page.url()}`);
      return;
    } catch (error) {
      logStep(`ensurePortalHome:retry attempt=${attempt + 1} url=${page.url()}`);
      if (attempt === 5) {
        throw error;
      }

      const loginButton = page.getByRole('button', { name: 'Sign In' });
      if (page.url().includes('/keycloak/') && await loginButton.isVisible().catch(() => false)) {
        if (user) {
          await loginUser(page, user).catch(() => {});
        } else {
          await loginButton.click().catch(() => {});
        }
      } else if (page.url().startsWith(`https://${newOrgName}.portal.localhost:8443/`)) {
        await page.reload({ waitUntil: 'networkidle' }).catch(() => {});
      }

      await page.waitForTimeout(5000);
    }
  }
}

async function switchToOrganization(page: Page, user: TestUser, createIfMissing: boolean): Promise<void> {
  const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button');

  if (createIfMissing) {
    const onboardButton = page.locator('[test-id="organization-management-onboard-button"]').locator('button');
    const switchReady = await switchButton.isEnabled().catch(() => false);
    if (!switchReady && await onboardButton.isVisible().catch(() => false)) {
      await fillOrganizationField(page, newOrgName);
      await onboardButton.click();
      await expect.poll(async () => ({
        enabled: await switchButton.isEnabled().catch(() => false),
        title: await switchButton.getAttribute('title').catch(() => ''),
      }), { timeout: Number(orgReadyTimeoutSeconds) * 1000 }).toMatchObject({ enabled: true });
    }
  }

  await fillSwitchOrganizationField(page, newOrgName);
  await switchButton.waitFor({ state: 'visible', timeout: 60000 });
  await expect.poll(async () => ({
    enabled: await switchButton.isEnabled().catch(() => false),
    title: await switchButton.getAttribute('title').catch(() => ''),
  }), { timeout: Number(orgReadyTimeoutSeconds) * 1000 }).toMatchObject({ enabled: true });
  await switchButton.click();

  await page.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {});
  await waitForAuthUsableState(page);
  await loginToInitialKeycloak(page, user);

  await completeAccountSetup(page, user);
  await gotoWithRetry(page, `https://${newOrgName}.portal.localhost:8443/home`);
  await ensurePortalHome(page, user);
}

export { ensurePortalHome, ensureWelcomePage, switchToOrganization };
