import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    ignoreHTTPSErrors: true,
    video: process.env.VIDEO === 'true' ? 'on' : 'off',
  },
});