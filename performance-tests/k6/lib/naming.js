// テストデータの命名規約 (sns-board performance-tests/k6/lib/naming.js 完全踏襲)。
// RUN_ID 接頭辞で cleanup を確実にする。E2E は e2e_ prefix (e2e/helpers/naming.js) で分離。

import { randomString } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

function generateRunId() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const ymd = `${now.getUTCFullYear()}${pad(now.getUTCMonth() + 1)}${pad(now.getUTCDate())}`;
  const hms = `${pad(now.getUTCHours())}${pad(now.getUTCMinutes())}${pad(now.getUTCSeconds())}`;
  const rand = randomString(6, 'abcdefghijklmnopqrstuvwxyz0123456789');
  return `${ymd}_${hms}_${rand}`;
}

export const RUN_ID = __ENV.K6_RUN_ID || generateRunId();
const SHORT_ID = RUN_ID.slice(-6);

export function makeEmail(index) {
  return `perf_${SHORT_ID}_${String(index).padStart(3, '0')}@perf.local`;
}

export function makeDisplayName(index) {
  return `Perf ${SHORT_ID} ${index}`;
}

// trip タイトル / 本文に RUN_ID タグを埋め込む。MySQL 直接 SELECT で grep 可能。
export function tagTripTitle(text) {
  return `[PERF_RUN:${RUN_ID}] ${text}`;
}
