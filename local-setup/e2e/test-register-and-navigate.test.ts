import test, { expect } from '@playwright/test';

test.describe('Home Page', () => {
  test('Register and navigate to portal', async ({ page }) => {
    await page.goto('http://localhost:8000/');

    // Interact with the page
    await page.click('text=Register');

    // Fill in registration form
    await page.fill('input[name="email"]', 'username@sap.com');
    await page.fill('input[id="password"]', 'MyPass1234');
    await page.fill('input[id="password-confirm"]', 'MyPass1234');
    await page.fill('input[id="firstName"]', 'Firstname');
    await page.fill('input[id="lastName"]', 'Lastname');
    await page.click('input[value="Register"]');

    await page.waitForURL('http://localhost:8000/home/overview', { timeout: 4000 }).then(() => {
      console.log('URL changed to /home/overview');
    });

    const title = await page.title();
    expect(title).toBe('OpenMFP Portal');
  });

});
