// web-vitals 4.x を CDN inject して LCP / FCP / CLS / INP / TTFB を回収する (sns-board 踏襲)。
// 本 PR (Pivot-3 PR-A) では smoke のみで使わないが、後続 PR-E の perf spec で利用するため雛形を配置。

const WEB_VITALS_CDN = 'https://unpkg.com/web-vitals@4/dist/web-vitals.iife.js';

export async function attachWebVitals(context) {
  await context.addInitScript(`
    (() => {
      window.__webVitals = window.__webVitals || {};
      const s = document.createElement('script');
      s.src = '${WEB_VITALS_CDN}';
      s.async = true;
      s.onload = () => {
        const wv = window.webVitals;
        if (!wv) return;
        const store = (metric) => {
          window.__webVitals[metric.name] = {
            value: metric.value,
            rating: metric.rating,
            id: metric.id,
          };
        };
        wv.onLCP(store);
        wv.onFCP(store);
        wv.onCLS(store);
        wv.onINP(store);
        wv.onTTFB(store);
      };
      document.documentElement.appendChild(s);
    })();
  `);
}

export async function readWebVitals(page, { timeout = 5000 } = {}) {
  await page.waitForFunction(
    () => window.__webVitals && Object.keys(window.__webVitals).length > 0,
    null,
    { timeout },
  ).catch(() => {});
  return page.evaluate(() => window.__webVitals || {});
}

export async function readNavigationTiming(page) {
  return page.evaluate(() => {
    const [nav] = performance.getEntriesByType('navigation');
    if (!nav) return null;
    return {
      dns: nav.domainLookupEnd - nav.domainLookupStart,
      tcp: nav.connectEnd - nav.connectStart,
      ttfb: nav.responseStart - nav.requestStart,
      response: nav.responseEnd - nav.responseStart,
      domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
      load: nav.loadEventEnd - nav.startTime,
      transferSize: nav.transferSize,
      encodedBodySize: nav.encodedBodySize,
    };
  });
}

export class StepTimer {
  constructor(label) {
    this.label = label;
    this.t0 = Date.now();
  }
  end() {
    return Date.now() - this.t0;
  }
}
