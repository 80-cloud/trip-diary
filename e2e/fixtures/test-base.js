// Playwright test fixture 拡張 (sns-board 踏襲)。
// 全 test で web-vitals 自動 inject + RUN_ID 共有。

import { test as base, expect } from '@playwright/test';
import { attachWebVitals, readWebVitals, readNavigationTiming } from '../helpers/web-vitals-collector.js';
import { RUN_ID } from '../helpers/naming.js';

export const test = base.extend({
  context: async ({ context }, use) => {
    await attachWebVitals(context);
    await use(context);
  },

  webVitals: async ({ page }, use) => {
    const reader = {
      read: (opts) => readWebVitals(page, opts),
      navigation: () => readNavigationTiming(page),
    };
    await use(reader);
  },
});

export { expect };
export { RUN_ID };
