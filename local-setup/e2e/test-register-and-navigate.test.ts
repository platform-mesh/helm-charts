import test, { expect } from '@playwright/test';

test.describe('Home Page', () => {
  test('Register and navigate to portal', async ({ page }) => {
    await page.goto('https://portal.dev.local:8443/');

    // Interact with the page
    await page.click('text=Register');

    // Fill in registration form
    await page.fill('input[name="email"]', 'username@sap.com');
    await page.fill('input[id="password"]', 'MyPass1234');
    await page.fill('input[id="password-confirm"]', 'MyPass1234');
    await page.fill('input[id="firstName"]', 'Firstname');
    await page.fill('input[id="lastName"]', 'Lastname');

    // Wait for navigation after clicking register
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      page.click('input[value="Register"]')
    ]);

    const title = await page.title();
    expect(title).toBe('OpenMFP Portal');
  });
});
