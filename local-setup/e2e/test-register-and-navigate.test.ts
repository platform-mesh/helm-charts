import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';

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

  });
});
