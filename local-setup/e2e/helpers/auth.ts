import { expect, Page } from '@playwright/test';

import { newOrgName, portalBaseUrl, type TestUser } from './constants';
import { logStep } from './log';

async function loginUser(page: Page, user: TestUser): Promise<void> {
  await page.getByRole('textbox', { name: 'Email' }).fill(user.email);
  await page.getByRole('textbox', { name: 'Password' }).fill(user.password);
  await page.getByRole('button', { name: 'Sign In' }).click();
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

async function ensureWelcomePage(page: Page, user: TestUser): Promise<void> {
  await gotoWithRetry(page, portalBaseUrl);
  await page.waitForLoadState('domcontentloaded', { timeout: 10000 }).catch(() => {});

  await waitForAuthUsableState(page);

  await registerOrLoginUser(page, user);
  await page.waitForURL(`${portalBaseUrl}**`, { timeout: 10000 });
  await page.waitForLoadState('load', { timeout: 10000 });
  await expect(page.getByText('Welcome to the Platform Mesh Portal!')).toBeVisible({ timeout: 5000 });
}

async function ensurePortalHome(page: Page): Promise<void> {
  const welcome = page.getByText("Welcome! Let's get started.", { exact: true });

  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      logStep(`ensurePortalHome:attempt=${attempt + 1} url=${page.url()}`);
      if (!page.url().startsWith(`https://${newOrgName}.portal.localhost:8443/`)) {
        await page.waitForURL(`https://${newOrgName}.portal.localhost:8443/**`, { timeout: 15000 });
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
        await loginButton.click().catch(() => {});
      } else if (page.url().startsWith(`https://${newOrgName}.portal.localhost:8443/`)) {
        await page.reload({ waitUntil: 'networkidle' }).catch(() => {});
      }

      await page.waitForTimeout(5000);
    }
  }
}

async function switchToOrganization(page: Page, user: TestUser, createIfMissing: boolean): Promise<void> {
  const orgInput = page.locator('[test-id="organization-management-input"]').locator('input');
  const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button');
  await orgInput.fill(newOrgName);

  if (createIfMissing) {
    const onboardButton = page.locator('[test-id="organization-management-onboard-button"]').locator('button');
    const switchReady = await switchButton.isEnabled().catch(() => false);
    if (!switchReady && await onboardButton.isVisible().catch(() => false)) {
      await onboardButton.click();
      await expect(orgInput).toHaveValue(newOrgName, { timeout: 5000 });
    }
  }

  await switchButton.waitFor({ state: 'visible', timeout: 60000 });
  await expect(switchButton).toBeEnabled({ timeout: 100000 });
  await switchButton.click();

  await page.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {});
  await waitForAuthUsableState(page);
  await page.getByRole('textbox', { name: 'Email' }).fill(user.email);
  await page.getByRole('textbox', { name: 'Password' }).fill(user.keycloakPassword);
  await page.getByRole('button', { name: 'Sign In' }).click();

  await completeAccountSetup(page, user);
  await ensurePortalHome(page);
}

export { ensurePortalHome, ensureWelcomePage, switchToOrganization };
