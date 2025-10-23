import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';
const testAccountName = 'testaccount3';
const userEmail = 'username3@sap.com';
const userPassword = 'MyPass1234';
const firstName = 'Firstname';
const lastName = 'Lastname';

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

    // Click the button AND wait for the subsequent navigation to finish
    await Promise.all([
        newPage.waitForURL(
          /https:\/\/(default\.)?portal\.dev\.local:8443\/.*/,
          { timeout: 10000 }
        ), // Wait for the URL to change
        newPage.getByRole('button', { name: 'Switch' }).click()
    ]);

    await newPage.screenshot({ path: 'screenshot-afterswitch.png' });

    // Now the page is fully loaded, try to find the text
    const loginText = await newPage.getByText("Sign in to your account");
    await expect(loginText).toBeVisible({ timeout: 10000 });

    await newPage.screenshot({ path: 'post-login.png' });

    // Perform register
    await newPage.getByText('Register').click();

    await registerNewUser(newPage);

    const newPage2 = await activateUserEmailViaMailpit(newPage, userEmail);

    await newPage2.screenshot({ path: 'register-2-after.png' });

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
