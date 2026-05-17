// Rails JWT HttpOnly Cookie 認証ヘルパー (sns-board lib/auth.js 踏襲)。
//
// 重要: k6 v2 の default cookie jar は iteration 境界でリセットされるため、
// signup レスポンスの cookie 値を module-level に保存し、毎 iter で cookieJar に
// 再注入する。default() 冒頭で必ず ensureAuth(index) を呼ぶこと。
//
// trip-diary 固有: Cookie 名は trip_diary_token (Rails encrypted JWT)。
// 値は opaque base64 文字列で、Rails 側で復号される。

import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL } from './config.js';
import { makeEmail, makeDisplayName } from './naming.js';

// 既定パスワード (User model: minimum 6)
export const DEFAULT_PASSWORD = 'PerfPass1234!';

// Cookie 名 (backend/app/controllers/application_controller.rb COOKIE_NAME = :trip_diary_token)
const ACCESS_COOKIE_NAME = 'trip_diary_token';

// VU local (module-level) に cookie 値を保持。VU ごとに別 JS context なので衝突しない。
let storedCookieValue = null;
let storedUser = null;

/**
 * 新規ユーザを signup で作成し、cookie 値を抽出して module 内に保存する。
 */
export function signup(index) {
  const email = makeEmail(index);
  const display_name = makeDisplayName(index);
  const res = http.post(
    `${BASE_URL}/api/v1/signup`,
    JSON.stringify({ email, display_name, password: DEFAULT_PASSWORD }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'auth_signup' } }
  );
  check(res, { 'signup 201': (r) => r.status === 201 });
  if (res.status !== 201) {
    throw new Error(`signup failed: ${res.status} ${res.body}`);
  }
  const cookies = res.cookies[ACCESS_COOKIE_NAME];
  if (!cookies || cookies.length === 0) {
    throw new Error(`signup response missing ${ACCESS_COOKIE_NAME} cookie`);
  }
  return { email, display_name, cookieValue: cookies[0].value };
}

/**
 * 毎 iter 冒頭で呼ぶ。初回呼出時に signup → 以降は保存済 cookie を cookieJar に注入。
 */
export function ensureAuth(index) {
  if (!storedCookieValue) {
    const result = signup(index);
    storedCookieValue = result.cookieValue;
    storedUser = { email: result.email, display_name: result.display_name };
  }
  http.cookieJar().set(BASE_URL, ACCESS_COOKIE_NAME, storedCookieValue, { path: '/' });
  return storedUser;
}
