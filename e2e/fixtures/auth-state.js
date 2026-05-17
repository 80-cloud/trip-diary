// 各 spec で signup → login state を構築するヘルパー。
//
// 設計判断 (sns-board と差分):
//   sns-board は Spring の opaque cookie 値をそのまま BrowserContext に注入できたが、
//   trip-diary は Rails の encrypted cookie 値で format が壊れて再利用できない。
//   そのため signup は API (テストデータ準備の高速化) で行い、login は UI 経由で実行
//   して Cookie をブラウザに自然に取得させる。
//
// 重複ログインを避けるため、ApiSession の cookie は spec から無視し、
// user の作成情報 (email / password) のみ返す。

import { ApiSession } from '../helpers/api-client.js';
import { LoginPage } from '../pages/LoginPage.js';
import { INDEX_BAND } from '../helpers/naming.js';

/**
 * 指定 index で新規ユーザを作成 (API) + UI で login して認証済み状態にする。
 *
 * @param {import('@playwright/test').Page} page
 * @param {import('@playwright/test').BrowserContext} context
 * @param {number} index
 * @returns {Promise<{email:string,display_name:string,password:string,user:object,session:ApiSession}>}
 */
export async function signupAndLogin(page, context, index) {
  const session = new ApiSession();
  const { email, display_name, password, user } = await session.signup(index);

  // UI ログイン: Cookie はブラウザが自然に取得し、以降の API call で送信される
  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login(email, password);
  await page.waitForURL(/\/(?!login)/, { timeout: 10_000 });

  return { email, display_name, password, user, session };
}

export { INDEX_BAND };
