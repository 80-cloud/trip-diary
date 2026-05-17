// POST/DELETE /api/v1/trips/:id/like の SLO (p95 < 300ms / 要件定義書 §4-1) を実測。
//
// 設計メモ:
// - 各 VU 初回 iter で signup + 自分の trip を 1 件作成し tripId 保存。
// - 以降の iter で POST → DELETE を交互に実行 (冪等性は backend が担保 / 重複 like は 200)。
// - 自分の trip にいいねする (他人の trip へのいいねでも同パスだが、本テストでは単純化)。
// - tags name は like_add / like_remove で分け、両方の p95 を SLO assert する。

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
    like: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    ...COMMON_THRESHOLDS,
    'http_req_duration{name:like_add}':    [`p(95)<${SLO_MS.like}`],
    'http_req_duration{name:like_remove}': [`p(95)<${SLO_MS.like}`],
  },
};

let myTripId = null;

function createTrip() {
  const today = new Date().toISOString().slice(0, 10);
  const res = http.post(
    `${BASE_URL}/api/v1/trips`,
    JSON.stringify({
      title: tagTripTitle(`like_vu${__VU}_setup`),
      destination: '沖縄',
      started_on: today,
      ended_on: today,
      body: 'perf like setup body',
      category: 'domestic',
      visibility: 'public',
      status: 'published',
    }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'like_setup' } }
  );
  if (res.status !== 201) {
    throw new Error(`like setup failed VU=${__VU}: ${res.status} ${res.body}`);
  }
  return res.json('id');
}

export default function () {
  ensureAuth(__VU);

  if (myTripId === null) {
    myTripId = createTrip();
    if (__VU === 1) {
      console.log(`[like] RUN_ID=${RUN_ID} VUS=${VUS} DURATION=${DURATION} SLO=${SLO_MS.like}ms tripId=${myTripId}`);
    }
  }

  const addRes = http.post(`${BASE_URL}/api/v1/trips/${myTripId}/like`, null, {
    tags: { name: 'like_add' },
  });
  check(addRes, { 'like_add 2xx': (r) => r.status === 200 || r.status === 201 });

  const delRes = http.del(`${BASE_URL}/api/v1/trips/${myTripId}/like`, null, {
    tags: { name: 'like_remove' },
  });
  check(delRes, { 'like_remove 2xx': (r) => r.status === 200 || r.status === 204 });
}
