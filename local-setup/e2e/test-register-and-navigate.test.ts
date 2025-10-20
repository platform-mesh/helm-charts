import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';
const testaccountName = 'testaccount';

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

test.describe('Home Page', () => {
  const userEmail = 'username@sap.com';
  const userPassword = 'MyPass1234';
  const firstName = 'Firstname';
  const lastName = 'Lastname';

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto(portalBaseUrl);
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

    const newPage = await activateUserEmailViaMailpit(page, userEmail);

    // Wait for the new page to load and check for the existence of specific text
    await newPage.waitForLoadState('domcontentloaded');
    const verificationText = await newPage.getByText("Welcome to the Platform Mesh Portal!");
    await expect(verificationText).toBeVisible();

    await newPage.screenshot({ path: 'screenshot-beforeswitch.png' });

    await newPage.getByRole('button', { name: 'Switch' }).click();

    await newPage.screenshot({ path: 'screenshot-afterswitch.png' });

    const loginText = await newPage.getByText("Sign in to your account");
    await expect(loginText).toBeVisible();

    await newPage.screenshot({ path: 'post-login.png' });

    // Perform register
    await newPage.getByText('Register').click();

    await newPage.fill('input[id="email"]', userEmail);
    await newPage.fill('input[id="password"]', userPassword);
    await newPage.fill('input[id="password-confirm"]', userPassword);
    await newPage.fill('input[id="firstName"]', firstName);
    await newPage.fill('input[id="lastName"]', lastName);

    await newPage.locator('input[value="Register"]').click();
    const newPage2 = await activateUserEmailViaMailpit(newPage, userEmail);
    const welcomeText = await newPage2.getByText("Welcome! Let's get started.");
    await expect(welcomeText).toBeVisible();
    await newPage2.getByText('Accounts').click();
    
    // click on "Create" button
    await newPage2.getByRole('button', { name: 'Create' }).click();

    // await newPage2.pause();

    await newPage2.locator('.ui5-select-icon > .ui5-icon-root').click();
    await newPage2.locator('#ui5wc_10-content > .ui5-li-text-wrapper').click();
    await newPage2.locator('#inner').nth(1).click();
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').click();
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').click();
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').press('Shift+Home');
    await newPage2.locator('ui5-input').filter({ hasText: '<svg xmlns="http://www.w3.org' }).locator('#inner').fill(testaccountName);
    await newPage2.getByRole('button', { name: 'Submit Emphasized' }).click();

    
    await newPage2.getByText(testaccountName).click();
    const download1Promise = newPage2.waitForEvent('download');
    await newPage2.getByRole('button', { name: 'Download kubeconfig Emphasized' }).click();
    const download1 = await download1Promise;
    await newPage2.getByTestId('luigi-topnav-title').click();
    await newPage2.getByTestId('accounts_accounts').click();
    
    await newPage2.pause();

    const accountText = await newPage2.getByText(testaccountName);
    await expect(accountText).toBeVisible();

  });
});
