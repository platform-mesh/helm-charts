import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';

async function activateUserEmailViaMailpit(
  page: Page,
  userEmail: string
) {
  await page.goto(`${portalBaseUrl}mailpit/`);

  await page.click(`text=To: ${userEmail}`)

  const emailFrame = page.frameLocator('#preview-html');

  await emailFrame.locator('text=Link to e-mail address verification').click();

}
test.describe('Home Page', () => {
  // Define user parameters
  const userEmail = 'username@sap.com';
  const userPassword = 'MyPass1234';
  const firstName = 'Firstname';
  const lastName = 'Lastname';

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto(portalBaseUrl);

    // Interact with the page
    await page.click('text=Register');

    // Fill in registration form
    await page.fill('input[name="email"]', userEmail);
    await page.fill('input[id="password"]', userPassword);
    await page.fill('input[id="password-confirm"]', userPassword);
    await page.fill('input[id="firstName"]', firstName);
    await page.fill('input[id="lastName"]', lastName);

    // Wait for navigation after clicking register
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      page.click('input[value="Register"]')
    ]);

    // await page.screenshot({ path: 'screenshot-after-register.png' });

    await activateUserEmailViaMailpit(page, userEmail);

    await page.goto(portalBaseUrl);

    await page.textContent('text=Welcome to the Platform Mesh Portal!');


    await page.screenshot({ path: 'screenshot-final.png' });

    const title = await page.title();
    expect(title).toBe('Platform Mesh Portal');
  });
});
