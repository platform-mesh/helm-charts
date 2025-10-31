import test, { expect, Page } from '@playwright/test';

// Simple JWT decoder (for debugging only)
function decodeJwt(token: string) {
  try {
    const [, payload] = token.split('.');
    return JSON.parse(Buffer.from(payload, 'base64').toString('utf-8'));
  } catch {
    return null;
  }
}

// Add this helper to attach a response header logger to a page
function attachHeaderLogger(page: Page, label: string, onToken?: (t: string) => void) {
  page.on('response', async (response) => {
    // Log only main document loads; remove this if you want all responses
    if (response.request().resourceType() === 'document') {
      // const headers = response.headers();
      // console.log(`[${label}] ${response.status()} ${response.url()}`);
      // for (const [k, v] of Object.entries(headers)) {
      //   console.log(`  ${k}: ${v}`);
      // }
      // Extract id_token_hint from the URL if present
      try {
        const u = new URL(response.url());
        const idTokenHint = u.searchParams.get('id_token_hint');
        if (idTokenHint) {
          console.log(`[${label}] id_token_hint: ${idTokenHint}`);
          if (onToken) onToken(idTokenHint);
          const decoded = decodeJwt(idTokenHint);
          if (decoded) console.log(`[${label}] id_token_hint (decoded):`, decoded);
        }
      } catch {}
    }
  });

  // Also watch outgoing requests (sometimes easier to catch query params here)
  page.on('request', (request) => {
    const url = request.url();
    if (url.includes('/protocol/openid-connect/') && url.includes('id_token_hint=')) {
      const u = new URL(url);
      const idTokenHint = u.searchParams.get('id_token_hint');
      if (idTokenHint) {
        console.log(`[${label}] request id_token_hint: ${idTokenHint}`);
        if (onToken) onToken(idTokenHint);
      }
    }
  });
}
const registerUrl = 'https://portal.dev.local:8443/keycloak/realms/welcome/protocol/openid-connect/auth?client_id=security-admin-console&redirect_uri=https%3A%2F%2Fportal.dev.local%3A8443%2Fkeycloak%2Fadmin%2Fwelcome%2Fconsole%2F&state=de1c861f-d29f-4689-a4b0-8e308cd1e88d&response_mode=query&response_type=code&scope=openid&nonce=6ed3b955-231a-419c-b755-c95251aeb8d5&code_challenge=QP8xRP91gSuDSj6OLurI70dRUh1p2Dp7JPJ_5N2Uh4Q&code_challenge_method=S256';
const portalBaseUrl = 'https://portal.dev.local:8443/';
const userEmail = 'minimal@sap.com';
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

  // Avoid networkidle; SPAs may never go idle
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'load' }),
    page.click('input[value="Register"]')
  ]);

  return page;
}

test.describe('Home Page', () => {

  test('Register and get Bearer token', async ({ page }) => {
    let capturedIdTokenFromUrl: string | undefined;

    attachHeaderLogger(page, 'root', (t) => (capturedIdTokenFromUrl = t));

    await page.goto(registerUrl);

    page = await registerNewUser(page);

    const newPage = await activateUserEmailViaMailpit(page, userEmail);
    attachHeaderLogger(newPage, 'verify', (t) => (capturedIdTokenFromUrl = t));

    await newPage.waitForLoadState('domcontentloaded');

    // logout
    await newPage.getByTestId('options-toggle').click();
    await newPage.getByRole('menuitem', { name: 'Sign out' }).click();

    const tokenResponsePromise = newPage.waitForResponse(
      (r) =>
        r.request().method() === 'POST' &&
        r.url().includes('/keycloak/realms/welcome/protocol/openid-connect/token'),
      { timeout: 30000 }
    );

    // login again
    await newPage.getByRole('textbox', { name: 'Email' }).fill(userEmail);
    await newPage.getByRole('textbox', { name: 'Password' }).fill(userPassword);
    await newPage.getByRole('button', { name: 'Sign In' }).click();

    const tokenResp = await tokenResponsePromise;
    const tokenJson = await tokenResp.json();
    const { access_token, id_token, refresh_token } = tokenJson || {};
    if (access_token) {
      console.log('[token] access_token:', access_token);
      const decoded = decodeJwt(access_token);
      if (decoded) console.log('[token] access_token (decoded):', decoded);
    }
    if (id_token) console.log('[token] id_token:', id_token);
    if (refresh_token) console.log('[token] refresh_token:', refresh_token);
    if (capturedIdTokenFromUrl) console.log('[url] id_token_hint captured from URL');

    // Hard-finish the test so CI doesn’t linger on open connections
    await newPage.context().close();
  });
});
