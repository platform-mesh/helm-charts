import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.localhost:8443/';
const testAccountName = 'testaccount';
const userEmail = 'username@sap.com';
const userPassword = 'MyPass1234';
const firstName = 'Firstname';
const lastName = 'Lastname';
const newOrgName = process.env.ORG_NAME || 'default';

const keycloakPassword = 'password';


async function loginUser(page: Page): Promise<void> {
  await page.getByRole('textbox', { name: 'Email' }).fill(userEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(userPassword);
  await page.getByRole('button', { name: 'Sign In' }).click();
}

async function registerOrLoginUser(page: Page): Promise<void> {
  await page.click('text=Register', { timeout: 5000 });
  await page.fill('input[name="email"]', userEmail);
  await page.fill('input[id="password"]', userPassword);
  await page.fill('input[id="password-confirm"]', userPassword);
  await page.fill('input[id="firstName"]', firstName);
  await page.fill('input[id="lastName"]', lastName);

  await page.click('input[value="Register"]', { timeout: 5000 });

  // Wait for either successful navigation or "Email already exists" error
  const emailExistsError = page.getByText('Email already exists.');
  const welcomeText = page.getByText('Welcome to the Platform Mesh Portal!');

  // Race between success and error conditions
  const result = await Promise.race([
    welcomeText.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'success'),
    emailExistsError.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'exists'),
  ]).catch(() => 'timeout');

  if (result === 'exists') {
    // User already exists, go back to login and sign in
    await page.getByRole('link', { name: 'Back to Login' }).click();
    await loginUser(page);
  }
}

async function completeAccountSetup(page: Page): Promise<void> {
  // Check if we're on the "Click here to proceed" page or directly on password update
  const proceedLink = page.getByRole('link', { name: 'Click here to proceed' });
  const newPasswordField = page.getByRole('textbox', { name: 'New Password' });

  // Wait for either the proceed link or password field to appear
  const firstElement = await Promise.race([
    proceedLink.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'proceed'),
    newPasswordField.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'password'),
  ]).catch(() => 'none');

  // Click proceed link if present
  if (firstElement === 'proceed') {
    await proceedLink.click();
    await newPasswordField.waitFor({ state: 'visible', timeout: 5000 });
  }

  // Fill password fields if visible
  if (firstElement === 'proceed' || firstElement === 'password') {
    await newPasswordField.fill(userPassword);
    await page.getByRole('textbox', { name: 'Confirm password' }).fill(userPassword);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  // Check if we need to fill first/last name
  const firstNameField = page.getByRole('textbox', { name: 'First name' });
  const backToAppLink = page.getByRole('link', { name: 'Back to Application' });

  const nextElement = await Promise.race([
    firstNameField.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'name'),
    backToAppLink.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'back'),
  ]).catch(() => 'none');

  if (nextElement === 'name') {
    await firstNameField.fill(firstName);
    await page.getByRole('textbox', { name: 'Last name' }).fill(lastName);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  // Click "Back to Application" if present
  const backLink = page.getByRole('link', { name: 'Back to Application' });
  const isBackLinkVisible = await backLink.isVisible().catch(() => false);
  if (isBackLinkVisible) {
    await backLink.click();
  }

  // Final login if we're on the login page
  const emailField = page.getByRole('textbox', { name: 'Email' });
  const isLoginPage = await emailField.isVisible().catch(() => false);
  if (isLoginPage) {
    await emailField.fill(userEmail);
    await page.getByRole('textbox', { name: 'Password' }).fill(userPassword);
    await page.getByRole('button', { name: 'Sign In' }).click();
  }
}

// Ensures we're on portal and the SPA finished routing
async function ensurePortalHome(page: Page) {
  await page.waitForURL('https://'+ newOrgName +'.portal.localhost:8443/**', { timeout: 10000 });
  await page.waitForLoadState('networkidle', { timeout: 10000 });
  const welcome = page.getByText("Welcome! Let's get started.", { exact: true });
  for (let i = 0; i < 3; i++) {
    try {
      await expect(welcome).toBeVisible({ timeout: 5000 });
      return;
    } catch (e) {
      if (i === 2) throw e;
      await page.reload({ waitUntil: 'networkidle' });
    }
  }
}

test.describe('Home Page', () => {

  test.setTimeout(90000);  // 90 seconds test timeout

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto(portalBaseUrl);

    await registerOrLoginUser(page);

    // Registration/login redirects to the welcome page
    await page.waitForURL(`${portalBaseUrl}**`, { timeout: 10000 });
    await page.waitForLoadState('load', { timeout: 10000 });
    const verificationText = page.getByText("Welcome to the Platform Mesh Portal!");
    await expect(verificationText).toBeVisible( { timeout: 5000 });

    await page.screenshot({ path: 'screenshot-beforeswitch.png' });

    // onboard 'default' organization and switch to it
    await page.locator('[test-id="organization-management-input"]').locator('input').fill(newOrgName);
    await page.locator('[test-id="organization-management-onboard-button"]').locator('button').click();

    // Verify the newly created org is selected in the combo box
    const orgInput = page.locator('[test-id="organization-management-input"]').locator('input');
    await expect(orgInput).toHaveValue(newOrgName, { timeout: 5000 });

    // Wait for the "Switch" button to become visible and enabled (org is ready), then click it
    const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button');
    await switchButton.waitFor({ state: 'visible', timeout: 60000 });
    await expect(switchButton).toBeEnabled({ timeout: 100000 });
    await switchButton.click();

    // Login via Keycloak with email and static password
    await page.getByRole('textbox', { name: 'Email' }).fill(userEmail);
    await page.getByRole('textbox', { name: 'Password' }).fill(keycloakPassword);
    await page.getByRole('button', { name: 'Sign In' }).click();

    // Complete account setup (handles both new and existing user flows)
    await completeAccountSetup(page);

    // Be explicit: make sure we're on the portal origin and the SPA has rendered
    await ensurePortalHome(page);

    await page.locator('[data-testid="accounts_accounts"]').click();
    // click on "Create" button
    await page.locator('[test-id="generic-list-view-create-button"]').click();

    await page.locator('[test-id="create-field-metadata_name"]').click();
    await page.locator('[test-id="create-field-spec_type"]').click();
    await page.locator('[test-id="create-field-spec_type-option-account"]').click();
    await page.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(testAccountName);
    await page.locator('[test-id="create-resource-submit"]').click();

    const accountElement = page.locator('[test-id="generic-list-cell-0-metadata.name"]').getByText(testAccountName);
    await expect(accountElement).toBeVisible( { timeout: 30000 } );

    await accountElement.click();
    const downloadButton = page.locator('[test-id="generic-detail-view-download"]');
    await expect(downloadButton).toBeVisible( { timeout: 5000 } );

    const download1Promise = page.waitForEvent('download');
    await downloadButton.click();
    const download = await download1Promise;
    expect(download).toBeDefined();

  });
});
