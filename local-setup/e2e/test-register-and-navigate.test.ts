import test, { expect, Page } from '@playwright/test';

const portalBaseUrl = 'https://portal.localhost:8443/';
const testAccountName = 'testaccount';
const userEmail = 'username@sap.com';
const userPassword = 'MyPass1234';
const firstName = 'Firstname';
const lastName = 'Lastname';
const newOrgName = process.env.ORG_NAME || 'default';
const inviteUserName = 'inviteusername@sap.com';
const testHttpBinName = 'test';

const keycloakPassword = 'password';


async function loginUser(page: Page): Promise<void> {
  await page.getByRole('textbox', { name: 'Email' }).fill(userEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(userPassword);
  await page.getByRole('button', { name: 'Sign In' }).click();
}

async function registerOrLoginUser(page: Page): Promise<void> {
  await page.click('text=Register', { timeout: 5000 });
  await page.fill('input[name="email"]', userEmail);
  await page.fill('input[id="password"]', userPassword);
  await page.fill('input[id="password-confirm"]', userPassword);
  await page.fill('input[id="firstName"]', firstName);
  await page.fill('input[id="lastName"]', lastName);

  await page.click('input[value="Register"]', { timeout: 5000 });

  // Wait for either successful navigation or "Email already exists" error
  const emailExistsError = page.getByText('Email already exists.');
  const welcomeText = page.getByText('Welcome to the Platform Mesh Portal!');

  // Race between success and error conditions
  const result = await Promise.race([
    welcomeText.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'success'),
    emailExistsError.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'exists'),
  ]).catch(() => 'timeout');

  if (result === 'exists') {
    // User already exists, go back to login and sign in
    await page.getByRole('link', { name: 'Back to Login' }).click();
    await loginUser(page);
  }
}

async function completeAccountSetup(page: Page): Promise<void> {
  // Check if we're on the "Click here to proceed" page or directly on password update
  const proceedLink = page.getByRole('link', { name: 'Click here to proceed' });
  const newPasswordField = page.getByRole('textbox', { name: 'New Password' });

  // Wait for either the proceed link or password field to appear
  const firstElement = await Promise.race([
    proceedLink.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'proceed'),
    newPasswordField.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'password'),
  ]).catch(() => 'none');

  // Click proceed link if present
  if (firstElement === 'proceed') {
    await proceedLink.click();
    await newPasswordField.waitFor({ state: 'visible', timeout: 5000 });
  }

  // Fill password fields if visible
  if (firstElement === 'proceed' || firstElement === 'password') {
    await newPasswordField.fill(userPassword);
    await page.getByRole('textbox', { name: 'Confirm password' }).fill(userPassword);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  // Check if we need to fill first/last name
  const firstNameField = page.getByRole('textbox', { name: 'First name' });
  const backToAppLink = page.getByRole('link', { name: 'Back to Application' });

  const nextElement = await Promise.race([
    firstNameField.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'name'),
    backToAppLink.waitFor({ state: 'visible', timeout: 5000 }).then(() => 'back'),
  ]).catch(() => 'none');

  if (nextElement === 'name') {
    await firstNameField.fill(firstName);
    await page.getByRole('textbox', { name: 'Last name' }).fill(lastName);
    await page.getByRole('button', { name: 'Submit' }).click();
  }

  // Click "Back to Application" if present
  const backLink = page.getByRole('link', { name: 'Back to Application' });
  const isBackLinkVisible = await backLink.isVisible().catch(() => false);
  if (isBackLinkVisible) {
    await backLink.click();
  }

  // Final login if we're on the login page
  const emailField = page.getByRole('textbox', { name: 'Email' });
  const isLoginPage = await emailField.isVisible().catch(() => false);
  if (isLoginPage) {
    await emailField.fill(userEmail);
    await page.getByRole('textbox', { name: 'Password' }).fill(userPassword);
    await page.getByRole('button', { name: 'Sign In' }).click();
  }
}

// Ensures we're on portal and the SPA finished routing
async function ensurePortalHome(page: Page) {
  await page.waitForURL('https://'+ newOrgName +'.portal.localhost:8443/**', { timeout: 10000 });
  await page.waitForLoadState('networkidle', { timeout: 10000 });
  const welcome = page.getByText("Welcome! Let's get started.", { exact: true });
  for (let i = 0; i < 3; i++) {
    try {
      await expect(welcome).toBeVisible({ timeout: 5000 });
      return;
    } catch (e) {
      if (i === 2) throw e;
      await page.reload({ waitUntil: 'networkidle' });
    }
  }
}

async function inviteUser(page: Page, userEmailToInvite: string): Promise<void> {
  // navigate to members page
  await page.locator('[data-testid="members_members"]').click();
  await page.waitForLoadState('networkidle', { timeout: 10000 });

  // click on add button to add a new member to the account
  const membersFrame = page.frameLocator('iframe[src*="organization/members"]');
  const addButton = membersFrame.locator('[data-testid="app-iam-member-list-add-button"]');
  await addButton.waitFor({ state: 'visible', timeout: 10000 });
  await expect(addButton).toBeEnabled({ timeout: 10000 });
  await addButton.scrollIntoViewIfNeeded();
  await addButton.click();

  // invite the user email by email 
  const addMembersFrame = page.frameLocator('iframe[src*="organization/add-members"]');
  const userInput = addMembersFrame.locator('[data-testid="app-iam-member-add-dialog-user-search-input"]').locator('input');
  await userInput.waitFor({ state: 'visible', timeout: 10000 });
  await userInput.fill(userEmailToInvite);
  await addMembersFrame.getByRole('button', { name: 'Select Options' }).click();
  await page.waitForTimeout(1000);

  // press add button to add a new member
  const inviteInFrame = addMembersFrame.locator('li.fd-combobox-list-item').filter({ hasText: 'Invite' }).filter({ hasText: userEmailToInvite });
  const inviteInPage = page.locator('li.fd-combobox-list-item').filter({ hasText: 'Invite' }).filter({ hasText: userEmailToInvite });
  const inviteOption = inviteInFrame.or(inviteInPage);
  await inviteOption.waitFor({ state: 'visible', timeout: 10000 });
  await inviteOption.click();
  await expect(addMembersFrame.getByRole('row').filter({ hasText: userEmailToInvite })).toBeVisible({ timeout: 15000 });
  await addMembersFrame.locator('[data-testid="app-iam-member-add-dialog-add-button"]').click();

  // verify invited user appears in the members list
  const memberEmailInList = membersFrame.locator('span.member-extra-information').filter({ hasText: userEmailToInvite });
  await expect(memberEmailInList).toBeVisible({ timeout: 15000 });
  await expect(memberEmailInList).toHaveText(userEmailToInvite);
}

test.describe('Home Page', () => {

  test.setTimeout(200000);  // 200 seconds test timeout

  test('Register and navigate to portal', async ({ page }) => {
    await page.goto(portalBaseUrl);

    await registerOrLoginUser(page);

    // Registration/login redirects to the welcome page
    await page.waitForURL(`${portalBaseUrl}**`, { timeout: 10000 });
    await page.waitForLoadState('load', { timeout: 10000 });
    const verificationText = page.getByText("Welcome to the Platform Mesh Portal!");
    await expect(verificationText).toBeVisible( { timeout: 5000 });

    await page.screenshot({ path: 'screenshot-beforeswitch.png' });

    // onboard 'default' organization and switch to it
    await page.locator('[test-id="organization-management-input"]').locator('input').fill(newOrgName);
    await page.locator('[test-id="organization-management-onboard-button"]').locator('button').click();

    // Verify the newly created org is selected in the combo box
    const orgInput = page.locator('[test-id="organization-management-input"]').locator('input');
    await expect(orgInput).toHaveValue(newOrgName, { timeout: 5000 });

    // Wait for the "Switch" button to become visible and enabled (org is ready), then click it
    const switchButton = page.locator('[test-id="organization-management-switch-button"]').locator('button');
    await switchButton.waitFor({ state: 'visible', timeout: 60000 });
    await expect(switchButton).toBeEnabled({ timeout: 100000 });
    await switchButton.click();

    // Login via Keycloak with email and static password
    await page.getByRole('textbox', { name: 'Email' }).fill(userEmail);
    await page.getByRole('textbox', { name: 'Password' }).fill(keycloakPassword);
    await page.getByRole('button', { name: 'Sign In' }).click();

    // Complete account setup (handles both new and existing user flows)
    await completeAccountSetup(page);

    // Be explicit: make sure we're on the portal origin and the SPA has rendered
    await ensurePortalHome(page);

    // verify user invite on organization level
    await inviteUser(page, inviteUserName);

    await page.locator('[data-testid="accounts_accounts"]').click();
    // click on "Create" button
    await page.getByRole('button', { name: 'Create', exact: true }).click();

    const accountCreateDialog = page.getByRole('dialog', { name: 'Create' });
    await accountCreateDialog.waitFor({ state: 'visible', timeout: 10000 });
    await page.getByRole('textbox').first().fill(testAccountName);

    // The account create form has a required ui5-select for "Type" (single value "account").
    // Open it via mouse click and select via keyboard since ui5-option click events don't
    // propagate through Playwright's locator-based clicks (popover lives in static area).
    const typeSelectInfo = await page.evaluate(() => {
      function find(root: Document | ShadowRoot): { x: number; y: number } | null {
        for (const el of Array.from(root.querySelectorAll('ui5-select'))) {
          const value = (el as any).value ?? el.getAttribute('value') ?? '';
          if (el.hasAttribute('required') && !value) {
            const rect = (el as HTMLElement).getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) {
              return { x: Math.round(rect.left + rect.width / 2), y: Math.round(rect.top + rect.height / 2) };
            }
          }
        }
        for (const el of Array.from(root.querySelectorAll('*'))) {
          if ((el as any).shadowRoot) {
            const found = find((el as any).shadowRoot);
            if (found) return found;
          }
        }
        return null;
      }
      return find(document);
    }).catch(() => null);
    if (typeSelectInfo) {
      await page.mouse.click(typeSelectInfo.x, typeSelectInfo.y);
      await page.waitForTimeout(500);
      await page.keyboard.press('ArrowDown');
      await page.waitForTimeout(100);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(300);
    }

    const accountSaveButton = page.getByRole('button', { name: 'Save' });
    await expect(accountSaveButton).toBeEnabled({ timeout: 10000 });
    await accountSaveButton.click();

    const accountElement = page.getByRole('row').filter({ hasText: testAccountName }).first();
    await expect(accountElement).toBeVisible( { timeout: 30000 } );

    // Wait for the account to be ready: navigate directly to account dashboard
    await accountElement.click();
    const downloadButton = page.getByRole('button', { name: 'Download kubeconfig' });
    await expect(downloadButton).toBeVisible( { timeout: 60000 } );

    const download1Promise = page.waitForEvent('download');
    await downloadButton.click();
    const download = await download1Promise;
    expect(download).toBeDefined();

    await page.locator('[data-testid="orchestrate_platform-mesh_io_httpbins_httpbins"]').click();

    const scopeCombobox = page.locator('[data-testid="namespace-selection-combobox"]').first();
    await expect(scopeCombobox).toBeVisible({ timeout: 15000 });

    await scopeCombobox.click();
    await scopeCombobox.press('F4');
    await expect(scopeCombobox).toHaveAttribute('open', '');

    const defaultScopeItem = page.locator('[data-testid="namespace-selection-combobox-item-default"]');
    await defaultScopeItem.waitFor({ state: 'visible', timeout: 10000 });
    await defaultScopeItem.click();
    await expect(scopeCombobox).toContainText('default');

    await page.getByRole('button', { name: 'Create' }).click();
    const httpBinCreateDialog = page.getByRole('dialog', { name: 'Create' });
    await httpBinCreateDialog.waitFor({ state: 'visible', timeout: 10000 });
    await page.getByRole('textbox').first().fill(testHttpBinName);
    await page.waitForTimeout(1000);
    const httpBinSaveButton = page.getByRole('button', { name: 'Save' });
    await expect(httpBinSaveButton).toBeEnabled({ timeout: 5000 });
    await httpBinSaveButton.click();

    // Wait for dialog to close
    await httpBinCreateDialog.waitFor({ state: 'hidden', timeout: 30000 });

    // Ensure http bin resource was created and appears in the list
    const httpBinNameCell = page.getByRole('row').filter({ hasText: testHttpBinName }).first();
    await expect(httpBinNameCell).toBeVisible({ timeout: 30000 });
  });
});
