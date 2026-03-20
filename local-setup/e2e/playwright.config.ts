import { defineConfig } from '@playwright/test';

const slowMo = Number(process.env.SLOW_MO || '0');

export default defineConfig({
  use: {
    ignoreHTTPSErrors: true,
    launchOptions: {
      slowMo: Number.isFinite(slowMo) ? slowMo : 0,
    },
    video: process.env.VIDEO === 'true' ? 'on' : 'off',
  },
});
