import { defineConfig, devices } from '@playwright/test';
const port = process.env.TEST_PORT || '18765';
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  workers: 1,
  timeout: 40_000,
  expect: { timeout: 12_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: { baseURL: `http://127.0.0.1:${port}`, trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  projects: process.env.TEST_BROWSER === 'firefox' ? [{name:'desktop-firefox',use:{...devices['Desktop Firefox']}}] : process.env.TEST_BROWSER === 'webkit' ? [{name:'mobile-webkit',use:{...devices['iPhone 13']}}] : [{ name: 'mobile-chromium', use: { ...devices['iPhone 13'], defaultBrowserType: 'chromium' } }],
  webServer: { command: 'node scripts/test-server.mjs', url: `http://127.0.0.1:${port}/api/v1/health`, timeout: 120_000, reuseExistingServer: false }
});
