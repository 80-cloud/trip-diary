import { defineConfig, devices } from '@playwright/test';

/**
 * trip-diary E2E Playwright 設定 (sns-board e2e/playwright.config.js 完全踏襲)
 * - Chromium desktop (CI smoke 主軸)
 * - WebKit desktop (Safari エンジン)
 * - iPhone Safari emulation (mobile)
 *
 * webServer: frontend (Nuxt 3011) を自動起動。backend (Rails 3010) / MySQL (3316) は手動 or CI service。
 * globalTeardown で e2e_<RUN_ID>_* データを残骸 0 まで掃除。
 */

const FRONTEND_URL = process.env.E2E_FRONTEND_URL || 'http://localhost:3011';
const isCI = !!process.env.CI;

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: isCI,
  retries: isCI ? 1 : 0,
  workers: 1,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
  ],
  timeout: 60_000,
  expect: {
    timeout: 10_000,
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.02,
      threshold: 0.2,
    },
  },
  globalTeardown: './helpers/cleanup.js',
  use: {
    baseURL: FRONTEND_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10_000,
    navigationTimeout: 15_000,
    extraHTTPHeaders: {
      'X-E2E-Test': '1',
    },
  },
  projects: [
    {
      name: 'chromium-desktop',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 800 },
      },
    },
    {
      name: 'webkit-desktop',
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 1280, height: 800 },
      },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 14'] },
    },
  ],
  webServer: {
    command: 'npm --prefix ../frontend run dev',
    url: FRONTEND_URL,
    reuseExistingServer: !isCI,
    timeout: 120_000,
    stdout: 'ignore',
    stderr: 'pipe',
  },
});
