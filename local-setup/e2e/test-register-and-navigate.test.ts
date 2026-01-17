import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.localhost:8443/';
const testAccountName = 'testaccount';
const userEmail = 'username@sap.com';
const userPassword = 'MyPass1234';
const firstName = 'Firstname';
const lastName = 'Lastname';
const newOrgName = 'default';

async function confirmInviteMailpit(
  page: Page,
  userEmail: string
): Promise<Page> {
  // Open mailpit in a new tab to avoid navigating away from the current page
  const mailpitPage = await page.context().newPage();
  await mailpitPage.goto(`${portalBaseUrl}mailpit/`);
  await mailpitPage.click(`text=To: ${userEmail} Update Your Account`, { timeout: 2*60*1000 });
  const emailFrame = mailpitPage.frameLocator('#preview-html');

  // Wait for the new page to open when clicking the verification link
  const [newPage] = await Promise.all([
    page.context().waitForEvent('page'),
    emailFrame.locator('text=Link to account update').click(),
  ]);

  // Close the mailpit tab
  await mailpitPage.close();

  return newPage;
}


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


    // Wait for the "Switch" button (role-based to pierce shadow DOM), and in parallel open Mailpit link
    let welcomePage: Page;
    const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button')

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

    await newPage2.locator('[data-testid="accounts_accounts"]').click();  // data-testid="accounts_accounts"
    // click on "Create" button
    await newPage2.locator('[test-id="generic-list-view-create-button"]').click(); // generic-list-view-create-button

    await newPage2.pause();
    
    await newPage2.locator('[test-id="create-field-metadata_name"]').click();
    await newPage2.locator('[test-id="create-field-spec_type"]').click();
    await newPage2.locator('[test-id="create-field-spec_type-option-account"]').click();
    await newPage2.locator('[test-id="create-field-metadata_name"]').getByRole('textbox').fill(testAccountName);
    await newPage2.locator('[test-id="create-resource-submit"]').click();

    const accountElement = newPage2.locator('[test-id="generic-list-cell-0-metadata.name"]').getByText(testAccountName);
    await expect(accountElement).toBeVisible( { timeout: 10000 } );
    
    // Close the Mailpit page/tab if it's still open
    const pages = newPage2.context().pages();
    for (const p of pages) {
      if (p.url().includes('mailpit') && p !== newPage2) {
        await p.close();
      }
    }
    
    await accountElement.click();
    const downloadButton = newPage2.locator('[test-id="generic-detail-view-download"]');
    await expect(downloadButton).toBeVisible( { timeout: 10000 } );

    await newPage2.pause();
    
    const download1Promise = newPage2.waitForEvent('download');
    await downloadButton.click();
    const download = await download1Promise;
    expect(download).toBeDefined();

  });
});
