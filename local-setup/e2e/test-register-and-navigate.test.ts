import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.dev.local:8443/';

async function activateUserEmailViaMailpit(
  page: Page,
  userEmail: string
) {
  await page.goto(`${portalBaseUrl}mailpit/`);
  await page.click(`text=To: ${userEmail}`);
  const emailFrame = page.frameLocator('#preview-html');
  await emailFrame.locator('text=Link to e-mail address verification').click();
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

    await activateUserEmailViaMailpit(page, userEmail);

    await page.screenshot({ path: 'screenshot-beforecheck.png' });

    await page.goto(portalBaseUrl);

    await page.screenshot({ path: 'screenshot-baseUrl.png' });


    await page.waitForSelector('text=Onboard a new organization', { state: 'visible' });
    
    
    // // Login
    // await page.waitForSelector('input[id="username"]', { state: 'visible' });
    // await page.fill('input[id="username"]', userEmail);
    // await page.fill('input[id="password"]', userPassword);
    // await page.click('text=Sign In');

    // await page.screenshot({ path: 'screenshot-after-login.png' });

    // const heading = await page.getByText("Welcome to the Platform Mesh Portal!");
    // await expect(heading).toBeVisible();
    // await page.screenshot({ path: 'screenshot-final.png' });

    // const title = await page.title();
    // expect(title).toBe('Platform Mesh Portal');
  });
});
