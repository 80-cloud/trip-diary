// タイムライン GET /api/v1/trips の SLO (p95 < 2.0s / 要件定義書 §4-1) を実測。
// GET /api/v1/trips は permitAll (未認証 OK) のため signup は呼ばない。

import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, SLO_MS, COMMON_THRESHOLDS, clampVusForProduction } from '../lib/config.js';
import { RUN_ID } from '../lib/naming.js';

const REQUESTED_VUS = Number(__ENV.K6_VUS || 10);
const VUS = clampVusForProduction(REQUESTED_VUS);
const DURATION = __ENV.K6_DURATION || '30s';

export const options = {
  scenarios: {
    timeline: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    ...COMMON_THRESHOLDS,
    'http_req_duration{name:timeline}': [`p(95)<${SLO_MS.timeline}`],
  },
};

export default function () {
  if (__ITER === 0 && __VU === 1) {
    console.log(`[timeline] RUN_ID=${RUN_ID} VUS=${VUS} DURATION=${DURATION} SLO=${SLO_MS.timeline}ms`);
  }
  const res = http.get(`${BASE_URL}/api/v1/trips`, { tags: { name: 'timeline' } });
  check(res, {
    'timeline 200': (r) => r.status === 200,
    'has trips': (r) => Array.isArray(r.json('trips')),
  });
}
