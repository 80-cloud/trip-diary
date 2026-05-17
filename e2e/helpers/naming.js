// E2E テストデータ命名規約 (sns-board e2e/helpers/naming.js を踏襲)。
// e2e_<SHORT_RUN_ID>_<index> パターン。MySQL 直接 SELECT で grep 可能。

import crypto from 'node:crypto';

function generateRunId() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const ymd = `${now.getUTCFullYear()}${pad(now.getUTCMonth() + 1)}${pad(now.getUTCDate())}`;
  const hms = `${pad(now.getUTCHours())}${pad(now.getUTCMinutes())}${pad(now.getUTCSeconds())}`;
  const rand = crypto.randomBytes(3).toString('hex');
  return `${ymd}_${hms}_${rand}`;
}

export const RUN_ID = process.env.E2E_RUN_ID || generateRunId();
const SHORT_ID = RUN_ID.slice(-6);

// trip-diary User model: password 最小 6 文字 (推定 / migrate 確認済)
export const DEFAULT_PASSWORD = 'E2EPass1234!';

export function makeUsername(index) {
  return `e2e_${SHORT_ID}_${String(index).padStart(3, '0')}`;
}

export function makeEmail(index) {
  return `${makeUsername(index)}@e2e.local`;
}

export function makeDisplayName(index) {
  return `E2E ${SHORT_ID} ${index}`;
}

// trip 識別用タグ。title / destination / body に埋め込み MySQL で grep 可能。
export function tagTripTitle(text) {
  return `[E2E:${RUN_ID}] ${text}`;
}

export function tagCommentBody(text) {
  return `[E2E:${RUN_ID}] ${text}`;
}

// 衝突回避のインデックス帯 (sns-board と同じ範囲)
export const INDEX_BAND = {
  STORAGE_STATE: 1,
  AUTH: 100,
  POSTS: 200,
  INTERACTIONS: 300,
  USERS: 400,
  SECURITY: 500,
  A11Y: 600,
  PERF: 700,
  VISUAL: 800,
  SMOKE: 900,
};
