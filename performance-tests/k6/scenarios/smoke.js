// 全 endpoint に 1 回ずつアクセスして 5xx ゼロを確認する最短シナリオ。
// VU=1 / 1 iteration。SLO assert はせず疎通のみ。
// sns-board performance-tests/k6/scenarios/smoke.js 完全踏襲 (endpoint のみ trip-diary 用)。

import http from 'k6/http';
import { check, group } from 'k6';
import { BASE_URL, COMMON_THRESHOLDS } from '../lib/config.js';
import { ensureAuth } from '../lib/auth.js';
import { tagTripTitle, RUN_ID } from '../lib/naming.js';

export const options = {
  scenarios: {
    smoke: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: '1m',
    },
  },
  thresholds: COMMON_THRESHOLDS,
};

export default function () {
  // setup() の signup は VU の cookie jar に伝播しないため default 内で ensureAuth を呼ぶ
  const user = ensureAuth(1);

  const jsonHeaders = { 'Content-Type': 'application/json' };

  group('health', () => {
    const res = http.get(`${BASE_URL}/api/v1/health`, { tags: { name: 'health' } });
    check(res, { 'health 200': (r) => r.status === 200 });
  });

  group('auth/me', () => {
    const res = http.get(`${BASE_URL}/api/v1/me`, { tags: { name: 'auth_me' } });
    check(res, { 'me 200': (r) => r.status === 200 });
  });

  let tripId;
  group('trip create', () => {
    const today = new Date().toISOString().slice(0, 10);
    const res = http.post(
      `${BASE_URL}/api/v1/trips`,
      JSON.stringify({
        title: tagTripTitle('smoke trip'),
        destination: '京都',
        started_on: today,
        ended_on: today,
        body: 'perf smoke body',
        category: 'domestic',
        visibility: 'public',
        status: 'published',
      }),
      { headers: jsonHeaders, tags: { name: 'trip_create' } }
    );
    check(res, { 'trip 201': (r) => r.status === 201 });
    tripId = res.json('id');
  });

  group('timeline', () => {
    const res = http.get(`${BASE_URL}/api/v1/trips`, { tags: { name: 'timeline' } });
    check(res, { 'timeline 200': (r) => r.status === 200 });
  });

  group('trip detail', () => {
    const res = http.get(`${BASE_URL}/api/v1/trips/${tripId}`, { tags: { name: 'trip_detail' } });
    check(res, { 'detail 200': (r) => r.status === 200 });
  });

  group('like add/remove', () => {
    const addRes = http.post(`${BASE_URL}/api/v1/trips/${tripId}/like`, null, {
      tags: { name: 'like_add' },
    });
    check(addRes, { 'like add 2xx': (r) => r.status === 200 || r.status === 201 });

    const delRes = http.del(`${BASE_URL}/api/v1/trips/${tripId}/like`, null, {
      tags: { name: 'like_remove' },
    });
    check(delRes, { 'like remove 2xx': (r) => r.status === 200 || r.status === 204 });
  });

  group('comment create', () => {
    const res = http.post(
      `${BASE_URL}/api/v1/trips/${tripId}/comments`,
      JSON.stringify({ body: tagTripTitle('smoke comment') }),
      { headers: jsonHeaders, tags: { name: 'comment_create' } }
    );
    check(res, { 'comment 201': (r) => r.status === 201 });
  });

  console.log(`[smoke] RUN_ID=${RUN_ID} user=${user.email} done`);
}
