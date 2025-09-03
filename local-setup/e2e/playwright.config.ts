import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    ignoreHTTPSErrors: true,
    // ...existing config
  },
});