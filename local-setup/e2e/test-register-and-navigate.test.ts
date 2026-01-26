import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.localhost:8443/';
const testAccountName = 'testaccount';
const userEmail = 'username@sap.com';
const userPassword = 'MyPass1234';
const firstName = 'Firstname';
const lastName = 'Lastname';
const newOrgName = 'default';

async function registerNewUser(
  page: Page): Promise<Page> {

  await page.click('text=Register', { timeout: 10000 });
  await page.fill('input[name="email"]', userEmail);
  await page.fill('input[id="password"]', userPassword);
  await page.fill('input[id="password-confirm"]', userPassword);
  await page.fill('input[id="firstName"]', firstName);
  await page.fill('input[id="lastName"]', lastName);

  await Promise.all([
    page.waitForNavigation({ waitUntil: 'load' }),
    page.click('input[value="Register"]', { timeout: 10000 })
  ]);

  return page;
}

// Ensures we’re on portal and the SPA finished routing
async function ensurePortalHome(page: Page) {
  await page.waitForURL('https://'+ newOrgName +'.portal.localhost:8443/**', { timeout: 20000 });
  await page.waitForLoadState('networkidle', { timeout: 20000 });
  const welcome = page.getByText("Welcome! Let's get started.", { exact: true });
  for (let i = 0; i < 3; i++) {
    try {
      await expect(welcome).toBeVisible({ timeout: 10000 });
      return;
    } catch (e) {
      if (i === 2) throw e;
      await page.reload({ waitUntil: 'networkidle' });
    }
  }
}

test.describe('Home Page', () => {

  test.setTimeout(2*60*1000);  // 2 minutes test timeout

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto(portalBaseUrl);

    await registerNewUser(page);

    // Registration now redirects directly to the welcome page
    await page.waitForURL(`${portalBaseUrl}**`, { timeout: 20000 });
    await page.waitForLoadState('load', { timeout: 20000 });
    const verificationText = page.getByText("Welcome to the Platform Mesh Portal!");
    await expect(verificationText).toBeVisible( { timeout: 10000 });

    await page.screenshot({ path: 'screenshot-beforeswitch.png' });

    // onboard 'default' organization and switch to it
    await page.locator('[test-id="organization-management-input"]').locator('input').fill(newOrgName);
    await page.locator('[test-id="organization-management-onboard-button"]').locator('button').click();


    // Wait for the "Switch" button (role-based to pierce shadow DOM)
    const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button')
    await switchButton.waitFor({ state: 'visible', timeout: 100000 });

    await switchButton.click();

    await page.getByRole('textbox', { name: 'Email' }).fill(userEmail);
    await page.getByRole('textbox', { name: 'Password' }).fill('password');
    await page.getByRole('button', { name: 'Sign In' }).click();
    await page.getByRole('textbox', { name: 'New Password' }).fill(userPassword);
    await page.getByRole('textbox', { name: 'Confirm password' }).fill(userPassword);
    await page.getByRole('button', { name: 'Submit' }).click();
    await page.getByRole('textbox', { name: 'First name' }).fill(firstName);
    await page.getByRole('textbox', { name: 'Last name' }).fill(lastName);
    await page.getByRole('button', { name: 'Submit' }).click();

    // Be explicit: make sure we’re on the portal origin and the SPA has rendered
    await ensurePortalHome(page);

    await page.locator('[data-testid="accounts_accounts"]').click();  // data-testid="accounts_accounts"
    // click on "Create" button
    await page.locator('[test-id="generic-list-view-create-button"]').click(); // generic-list-view-create-button

    await page.pause();

    await page.locator('[test-id="create-field-metadata_name"]').click();
    await page.locator('[test-id="create-field-spec_type"]').click();
    await page.locator('[test-id="create-field-spec_type-option-account"]').click();
    await page.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(testAccountName);
    await page.locator('[test-id="create-resource-submit"]').click();

    const accountElement = page.locator('[test-id="generic-list-cell-0-metadata.name"]').getByText(testAccountName);
    await expect(accountElement).toBeVisible( { timeout: 180000 } );

    await accountElement.click();
    const downloadButton = page.locator('[test-id="generic-detail-view-download"]');
    await expect(downloadButton).toBeVisible( { timeout: 10000 } );

    await page.pause();

    const download1Promise = page.waitForEvent('download');
    await downloadButton.click();
    const download = await download1Promise;
    expect(download).toBeDefined();

  });
});
