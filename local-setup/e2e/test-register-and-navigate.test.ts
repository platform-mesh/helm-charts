import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';
const testAccountName = 'testaccount1';
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

    await page.getByRole('link', { name: 'keycloak@portal.dev.local a' }).click();
    const page2Promise = page.waitForEvent('popup');
    await page.locator('#preview-html').contentFrame().getByRole('link', { name: 'Link to account update' }).click();
    const page2 = await page2Promise;
    await page2.getByRole('link', { name: '» Click here to proceed' }).click();
    await page2.getByRole('textbox', { name: 'New Password' }).fill(userPassword);
    await page2.getByRole('textbox', { name: 'Confirm password' }).click();
    await page2.getByRole('textbox', { name: 'Confirm password' }).fill(userPassword);
    await page2.getByRole('button', { name: 'Submit' }).click();
    await page2.getByRole('textbox', { name: 'First name' }).click();
    await page2.getByRole('textbox', { name: 'First name' }).fill(firstName);
    await page2.getByRole('textbox', { name: 'Last name' }).click();
    await page2.getByRole('textbox', { name: 'Last name' }).fill(lastName);
    await page2.getByRole('button', { name: 'Submit' }).click();
    await page2.getByRole('link', { name: '« Back to Application' }).click();
    await page2.getByRole('textbox', { name: 'Email' }).fill(userEmail);
    await page2.getByRole('textbox', { name: 'Password' }).click();
    await page2.getByRole('textbox', { name: 'Password' }).fill(userPassword);
    await page2.getByRole('button', { name: 'Sign In' }).click();



    const welcomeText = await page2.getByText("Welcome! Let's get started.");
    await expect(welcomeText).toBeVisible();
    await page2.getByText('Accounts').click();
    
    // click on "Create" button
    await page2.getByRole('button', { name: 'Create' }).click();

    // await page2.pause();

    await page2.locator('.ui5-select-icon > .ui5-icon-root').click();
    await page2.locator('#ui5wc_10-content > .ui5-li-text-wrapper').click();
    await page2.locator('#inner').nth(1).click();
    await page2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').click();
    await page2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').click();
    await page2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').press('Shift+Home');
    await page2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').fill(testAccountName);
    await page2.getByRole('button', { name: 'Submit Emphasized' }).click();

    const accountElement = await page2.getByText(testAccountName);
    await expect(accountElement).toBeVisible( { timeout: 10000 } );
    await accountElement.click();
    const download1Promise = page2.waitForEvent('download');
    const downloadButton = await page2.getByRole('button', { name: 'Download kubeconfig Emphasized' });
    await expect(downloadButton).toBeVisible( { timeout: 10000 } );
    await downloadButton.click();
    await expect(download1Promise).toBeDefined();
    await page2.getByTestId('luigi-topnav-title').click();
    await page2.getByTestId('accounts_accounts').click();

    await page2.pause();

    const accountText = await page2.getByText(testAccountName);
    await expect(accountText).toBeVisible( { timeout: 10000 } );

  });
});
