// GET /api/v1/trips/:id の SLO (p95 < 1000ms / 要件定義書 §4-1) を実測。
//
// 設計メモ:
// - 各 VU は初回 iter で signup + trip 1 件作成し、module-level 変数に tripId を保存。
// - 以降の iter は同じ trip に対して GET を繰り返す。
// - VU ごと別 trip にすることで N+1 検出や image preload の偏りを避ける。

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
    trip_detail: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    ...COMMON_THRESHOLDS,
    'http_req_duration{name:trip_detail}': [`p(95)<${SLO_MS.tripDetail}`],
  },
};

// VU local (module-level): 各 VU が作成した trip の id を保持
let myTripId = null;

function createTrip() {
  const today = new Date().toISOString().slice(0, 10);
  const res = http.post(
    `${BASE_URL}/api/v1/trips`,
    JSON.stringify({
      title: tagTripTitle(`detail_vu${__VU}_setup`),
      destination: '京都',
      started_on: today,
      ended_on: today,
      body: 'perf trip_detail setup body',
      category: 'domestic',
      visibility: 'public',
      status: 'published',
    }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'trip_detail_setup' } }
  );
  if (res.status !== 201) {
    throw new Error(`trip_detail setup failed VU=${__VU}: ${res.status} ${res.body}`);
  }
  return res.json('id');
}

export default function () {
  ensureAuth(__VU);

  if (myTripId === null) {
    myTripId = createTrip();
    if (__VU === 1) {
      console.log(`[trip_detail] RUN_ID=${RUN_ID} VUS=${VUS} DURATION=${DURATION} SLO=${SLO_MS.tripDetail}ms tripId=${myTripId}`);
    }
  }

  const res = http.get(`${BASE_URL}/api/v1/trips/${myTripId}`, { tags: { name: 'trip_detail' } });
  check(res, {
    'trip_detail 200': (r) => r.status === 200,
    'has id': (r) => r.json('id') === myTripId,
  });
}
