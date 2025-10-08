import test, { expect } from '@playwright/test';

async function activateUserEmail(page, adminUsername, adminPassword, userEmail) {
  await page.goto('https://portal.dev.local:8443/keycloak/');
  
  // Log in to Keycloak
  await page.fill('input[name="username"]', adminUsername);
  await page.fill('input[name="password"]', adminPassword);
  await page.click('button[type="submit"]');

  // Navigate to the user management section
  await page.goto('https://portal.dev.local:8443/keycloak/admin/master/console/#/welcome/users/');
  
  // Search for the user by email
  await page.fill('input[placeholder="Search user"]', userEmail);
  await page.click('button[type="submit"]');

  // Click on the user to activate
  await page.click(`text=${userEmail}`);

  // Wait for the "Email verified" toggle to be visible
  await page.waitForSelector('text=Email verified', { state: 'visible' });

  // Click on the "Email verified" toggle
  await page.click('text=Email verified');

  // Wait for the Save button to be visible
  await page.waitForSelector('text=Save', { state: 'visible' });

  // Save the changes
  await page.click('text=Save');

  // Logout from Keycloak
  await page.goto('https://portal.dev.local:8443/keycloak/realms/master/protocol/openid-connect/logout');
  await page.waitForSelector('text=Logout', { state: 'visible' });
  await page.click('text=Logout');
}

test.describe('Home Page', () => {
  // Define user parameters
  const userEmail = 'username13@sap.com';
  const userPassword = 'MyPass1234';
  const firstName = 'Firstname';
  const lastName = 'Lastname';

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto('https://portal.dev.local:8443/');

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

    // Activate the user's email in Keycloak
    await activateUserEmail(page, 'keycloak-admin', 'admin', userEmail);

    // Navigate to the portal
    await page.goto('https://portal.dev.local:8443/');

    // Wait for a specific element on the portal page to ensure it has loaded
    await page.waitForSelector('text=Welcome', { state: 'visible' }); // Adjust this selector based on your portal's content

    // Login to the portal
    await page.fill('input[name="username"]', userEmail);
    await page.fill('input[name="password"]', userPassword);
    await page.click('button[type="submit"]');

    // Wait for a specific element that indicates successful login
    await page.waitForSelector('text=Welcome to the Platform Mesh Portal!', { state: 'visible' }); // Adjust this selector based on your portal's content

    // await page.screenshot({ path: 'screenshot-after-signin.png' });
    
    const title = await page.title();
    expect(title).toBe('Platform Mesh Portal');
  });
});
