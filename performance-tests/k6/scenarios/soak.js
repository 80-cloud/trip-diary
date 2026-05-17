// 30 分 soak (持続負荷) シナリオ。Layer A の総仕上げ。
//
// 目的: 短時間の smoke / timeline では検出できない memory leak / DB connection pool 枯渇 /
//       slow query の累積など、時間経過で顕在化する degradation を捕まえる。
//
// 設計メモ:
// - VU=5 (デフォルト) で 30 min 持続。本番 URL なら clampVusForProduction で 5 にクランプ。
// - mixed workload: 1 iter で timeline / detail / create (希に) / like (toggle) を実行。
// - SLO assertion は各 endpoint の p95 を既存 SLO 値で固定 (timeline / tripDetail / tripCreate / like)。
// - 30 min 中の req 数想定: 5 VU × (timeline+detail+like add+like del = 4 req) × ~60 iter/min × 30 min
//                          = 約 36000 req。失敗率 1% 以内が COMMON_THRESHOLDS で監視される。
//
// 注意:
// - 30 min 実走には Rails dev mode + MySQL container が安定稼働している必要あり。
// - 本番 URL では実行禁止 (clampVusForProduction + warn でガード)。
// - 短時間動作確認は K6_DURATION=30s 等で上書き可。

import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, SLO_MS, COMMON_THRESHOLDS, clampVusForProduction } from '../lib/config.js';
import { ensureAuth } from '../lib/auth.js';
import { tagTripTitle, RUN_ID } from '../lib/naming.js';

const REQUESTED_VUS = Number(__ENV.K6_VUS || 5);
const VUS = clampVusForProduction(REQUESTED_VUS);
const DURATION = __ENV.K6_DURATION || '30m';

// trip_create は重い + 1 VU で大量に作りすぎないよう、N iter に 1 回だけ実行する。
const CREATE_EVERY_N = Number(__ENV.K6_SOAK_CREATE_EVERY || 50);
// iter 間 sleep (秒)。req/min 流量を緩める。0 で無休 (デフォルト 1s)。
const SLEEP_SEC = Number(__ENV.K6_SOAK_SLEEP || 1);

export const options = {
  scenarios: {
    soak: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    ...COMMON_THRESHOLDS,
    'http_req_duration{name:timeline}':    [`p(95)<${SLO_MS.timeline}`],
    'http_req_duration{name:trip_detail}': [`p(95)<${SLO_MS.tripDetail}`],
    'http_req_duration{name:trip_create}': [`p(95)<${SLO_MS.tripCreate}`],
    'http_req_duration{name:like_add}':    [`p(95)<${SLO_MS.like}`],
    'http_req_duration{name:like_remove}': [`p(95)<${SLO_MS.like}`],
  },
};

let myTripId = null;

function createTrip(label) {
  const today = new Date().toISOString().slice(0, 10);
  const res = http.post(
    `${BASE_URL}/api/v1/trips`,
    JSON.stringify({
      title: tagTripTitle(`soak_vu${__VU}_${label}`),
      destination: '北海道',
      started_on: today,
      ended_on: today,
      body: 'perf soak body',
      category: 'domestic',
      visibility: 'public',
      status: 'published',
    }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'trip_create' } }
  );
  check(res, { 'soak create 201': (r) => r.status === 201 });
  return res.status === 201 ? res.json('id') : null;
}

export default function () {
  ensureAuth(__VU);

  if (myTripId === null) {
    myTripId = createTrip('setup');
    if (__VU === 1) {
      console.log(`[soak] RUN_ID=${RUN_ID} VUS=${VUS} DURATION=${DURATION} CREATE_EVERY=${CREATE_EVERY_N} SLEEP=${SLEEP_SEC}s tripId=${myTripId}`);
    }
  }

  // 1: timeline (毎 iter)
  const tl = http.get(`${BASE_URL}/api/v1/trips`, { tags: { name: 'timeline' } });
  check(tl, { 'soak timeline 200': (r) => r.status === 200 });

  // 2: trip_detail (毎 iter)
  if (myTripId) {
    const td = http.get(`${BASE_URL}/api/v1/trips/${myTripId}`, { tags: { name: 'trip_detail' } });
    check(td, { 'soak detail 200': (r) => r.status === 200 });

    // 3: like toggle (毎 iter)
    const la = http.post(`${BASE_URL}/api/v1/trips/${myTripId}/like`, null, { tags: { name: 'like_add' } });
    check(la, { 'soak like_add 2xx': (r) => r.status === 200 || r.status === 201 });
    const lr = http.del(`${BASE_URL}/api/v1/trips/${myTripId}/like`, null, { tags: { name: 'like_remove' } });
    check(lr, { 'soak like_remove 2xx': (r) => r.status === 200 || r.status === 204 });
  }

  // 4: trip_create (N iter に 1 回 / DB 肥大化抑制)
  if (__ITER > 0 && __ITER % CREATE_EVERY_N === 0) {
    createTrip(`iter${__ITER}`);
  }

  if (SLEEP_SEC > 0) sleep(SLEEP_SEC);
}
