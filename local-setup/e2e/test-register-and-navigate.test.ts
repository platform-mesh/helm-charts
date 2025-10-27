import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';
const testAccountName = 'testaccount';
const userEmail = 'username@sap.com';
const userPassword = 'MyPass1234';
const firstName = 'Firstname';
const lastName = 'Lastname';
const newOrgName = 'default';

async function activateUserEmailViaMailpit(
  page: Page,
  userEmail: string
): Promise<Page> {
  await page.goto(`${portalBaseUrl}mailpit/`);
  await page.click(`text=To: ${userEmail}`);
  const emailFrame = page.frameLocator('#preview-html');

  // Wait for the new page to open when clicking the verification link
  const [newPage] = await Promise.all([
    page.context().waitForEvent('page'),
    emailFrame.locator('text=Link to e-mail address verification').click(),
  ]);

  return newPage;
}

async function confirmInviteMailpit(
  page: Page,
  userEmail: string
): Promise<Page> {

  await page.goto(`${portalBaseUrl}mailpit/`);
  await page.click(`text=To: ${userEmail} Update Your Account`);
  const emailFrame = page.frameLocator('#preview-html');

  // Wait for the new page to open when clicking the verification link
  const [newPage] = await Promise.all([
    page.context().waitForEvent('page'),
    emailFrame.locator('text=Link to account update').click(),
  ]);

  return newPage;
}


async function registerNewUser(
  page: Page): Promise<Page> {

  await page.click('text=Register');
  await page.fill('input[name="email"]', userEmail);
  await page.fill('input[id="password"]', userPassword);
  await page.fill('input[id="password-confirm"]', userPassword);
  await page.fill('input[id="firstName"]', firstName);
  await page.fill('input[id="lastName"]', lastName);

  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('input[value="Register"]')
  ]);

  return page;
}

// Ensures we’re on portal and the SPA finished routing
async function ensurePortalHome(page: Page) {
  await page.waitForURL('https://'+ newOrgName +'.portal.dev.local:8443/**', { timeout: 20000 });
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

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto(portalBaseUrl);

    page = await registerNewUser(page);
    
    const newPage = await activateUserEmailViaMailpit(page, userEmail);

    // Wait for the new page to load and check for the existence of specific text
    await newPage.waitForLoadState('domcontentloaded');
    const verificationText = await newPage.getByText("Welcome to the Platform Mesh Portal!");
    await expect(verificationText).toBeVisible();

    await newPage.screenshot({ path: 'screenshot-beforeswitch.png' });

    await newPage.pause();  // for debugging
    // onboard 'default' organization and switch to it
    await newPage.getByRole('textbox', { name: 'Onboard a new organization' }).fill(newOrgName);
    await newPage.getByRole('button', { name: 'Onboard Emphasized' }).click();

    // Wait for the "Switch" button (role-based to pierce shadow DOM), and in parallel open Mailpit link
    let welcomePage: Page;
    const switchButton = newPage.getByRole('button', { name: /Switch/i });

    const [_, wp] = await Promise.all([
      switchButton.waitFor({ state: 'visible', timeout: 100000 }),
      confirmInviteMailpit(page, userEmail),
    ]);
    welcomePage = wp;

    // Optionally click it after it is visible
    // await switchButton.click();

    await welcomePage.getByRole('link', { name: '» Click here to proceed' }).click();
    await welcomePage.getByRole('textbox', { name: 'New Password' }).fill(userPassword);
    await welcomePage.getByRole('textbox', { name: 'Confirm password' }).click();
    await welcomePage.getByRole('textbox', { name: 'Confirm password' }).fill(userPassword);
    await welcomePage.getByRole('button', { name: 'Submit' }).click();
    await welcomePage.getByRole('textbox', { name: 'First name' }).click();
    await welcomePage.getByRole('textbox', { name: 'First name' }).fill(firstName);
    await welcomePage.getByRole('textbox', { name: 'Last name' }).click();
    await welcomePage.getByRole('textbox', { name: 'Last name' }).fill(lastName);
    await welcomePage.getByRole('button', { name: 'Submit' }).click();
    await welcomePage.getByRole('link', { name: '« Back to Application' }).click();
    await welcomePage.getByRole('textbox', { name: 'Email' }).fill(userEmail);
    await welcomePage.getByRole('textbox', { name: 'Password' }).click();
    await welcomePage.getByRole('textbox', { name: 'Password' }).fill(userPassword);
    await welcomePage.getByRole('button', { name: 'Sign In' }).click();

    // Same-tab navigation; keep using the same handle and wait deterministically
    const newPage2 = welcomePage;

    // Be explicit: make sure we’re on the portal origin and the SPA has rendered
    await ensurePortalHome(newPage2);

    await newPage2.getByText('Accounts').click();
    // click on "Create" button
    await newPage2.getByRole('button', { name: 'Create' }).click();

    // await page2.pause();

    await newPage2.locator('.ui5-select-icon > .ui5-icon-root').click();
    await newPage2.locator('#ui5wc_10-content > .ui5-li-text-wrapper').click();
    await newPage2.locator('#inner').nth(1).click();
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').click();
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').click();
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').press('Shift+Home');
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').fill(testAccountName);
    await newPage2.getByRole('button', { name: 'Submit Emphasized' }).click();

    const accountElement = await newPage2.getByText(testAccountName);
    await expect(accountElement).toBeVisible( { timeout: 10000 } );
    await accountElement.click();
    const download1Promise = newPage2.waitForEvent('download');
    const downloadButton = await newPage2.getByRole('button', { name: 'Download kubeconfig Emphasized' });
    await expect(downloadButton).toBeVisible( { timeout: 10000 } );
    await downloadButton.click();
    await expect(download1Promise).toBeDefined();
    await newPage2.getByTestId('luigi-topnav-title').click();
    await newPage2.getByTestId('accounts_accounts').click();

    await newPage2.pause();

    const accountText = await newPage2.getByText(testAccountName);
    await expect(accountText).toBeVisible( { timeout: 10000 } );

  });
});
