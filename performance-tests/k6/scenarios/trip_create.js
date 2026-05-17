// POST /api/v1/trips の SLO (p95 < 500ms / 要件定義書 §4-1) を実測。
// VU ごと別 perf_XXX_NNN user で signup → trip を作成し続けるシナリオ。
//
// 設計メモ:
// - tag name: 'trip_create' を全 POST に付け、threshold で http_req_duration{name:trip_create} を絞る。
// - 30s × 10 VU で約 300-1000 trips が生成される (Rails dev mode で 100-300ms/req 想定)。
// - cleanup は scenario 終了後 `npm run perf:cleanup` で perf_% prefix を ActiveRecord 削除。

import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, SLO_MS, COMMON_THRESHOLDS, clampVusForProduction } from '../lib/config.js';
import { ensureAuth } from '../lib/auth.js';
import { tagTripTitle, RUN_ID } from '../lib/naming.js';

const REQUESTED_VUS = Number(__ENV.K6_VUS || 10);
const VUS = clampVusForProduction(REQUESTED_VUS);
const DURATION = __ENV.K6_DURATION || '30s';

export const options = {
  scenarios: {
    trip_create: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    ...COMMON_THRESHOLDS,
    'http_req_duration{name:trip_create}': [`p(95)<${SLO_MS.tripCreate}`],
  },
};

export default function () {
  ensureAuth(__VU);

  if (__ITER === 0 && __VU === 1) {
    console.log(`[trip_create] RUN_ID=${RUN_ID} VUS=${VUS} DURATION=${DURATION} SLO=${SLO_MS.tripCreate}ms`);
  }

  const today = new Date().toISOString().slice(0, 10);
  const res = http.post(
    `${BASE_URL}/api/v1/trips`,
    JSON.stringify({
      title: tagTripTitle(`vu${__VU}_iter${__ITER}`),
      destination: '東京',
      started_on: today,
      ended_on: today,
      body: 'perf trip_create body',
      category: 'domestic',
      visibility: 'public',
      status: 'published',
    }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'trip_create' } }
  );
  check(res, { 'trip_create 201': (r) => r.status === 201 });
}
