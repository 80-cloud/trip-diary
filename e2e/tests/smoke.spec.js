// Smoke spec: CI 自動実行される最短セット (要件定義書 §8 の Phase 3 E2E 必須シナリオ)。
// signup (API) → login (UI) → trip 作成 (API) → タイムライン表示 (UI)
//   → 詳細遷移 (UI) → コメント投稿 (UI) → いいね (UI) → ログアウト (UI)
//
// 設計意図:
//   - signup と trip 作成は API 経由でセットアップ (テストデータ準備を高速化)
//   - login は UI 経由 (Rails encrypted cookie の直接注入が壊れるため)
//   - UI 操作は「ログイン → タイムライン → 詳細 → コメント → いいね → ログアウト」のコア導線に集中
//   - trip 作成 UI / signup UI の詳細は後続 PR (posts/trip-crud.spec.js / auth/signup.spec.js) でカバー予定

import { test, expect } from '../fixtures/test-base.js';
import { signupAndLogin, INDEX_BAND } from '../fixtures/auth-state.js';
import { TripListPage } from '../pages/TripListPage.js';
import { TripDetailPage } from '../pages/TripDetailPage.js';
import { tagTripTitle, tagCommentBody } from '../helpers/naming.js';

test.describe('@smoke smoke', () => {
  test('signup → login → trip作成 → タイムライン → コメント → いいね → ログアウト', async ({ page, context }) => {
    let session;
    let trip;
    const tripTitle = tagTripTitle('smoke trip');
    const commentBody = tagCommentBody('smoke comment');

    await test.step('signup (API) + UI ログイン', async () => {
      ({ session } = await signupAndLogin(page, context, INDEX_BAND.SMOKE + 1));
      expect(session.user?.id).toBeTruthy();
    });

    await test.step('trip 作成 (API)', async () => {
      trip = await session.createTrip({ title: 'smoke trip' });
      expect(trip.id).toBeTruthy();
    });

    const tl = new TripListPage(page);

    await test.step('タイムラインに自分の trip が表示される', async () => {
      await tl.goto();
      // ヘッダーのログアウトボタン (= 認証済み判定) が出るまで待つ
      await expect(tl.logoutButton).toBeVisible();
      await expect(tl.cardByTitle(tripTitle)).toBeVisible();
    });

    const detail = new TripDetailPage(page);

    await test.step('詳細ページに遷移', async () => {
      await detail.gotoById(trip.id);
      await expect(detail.title).toHaveText(tripTitle);
    });

    await test.step('コメント投稿', async () => {
      await detail.submitComment(commentBody);
      await expect(page.getByText(commentBody)).toBeVisible({ timeout: 5000 });
    });

    await test.step('いいね切替', async () => {
      const before = await detail.likeButton.textContent();
      await detail.clickLike();
      // 楽観 UI: 「N いいね」のカウントが 0→1 に変わるまで待つ
      await expect(detail.likeButton).not.toHaveText(before || '', { timeout: 5000 });
      await expect(detail.likeButton).toContainText('1 いいね');
    });

    await test.step('ログアウト → /login へリダイレクト', async () => {
      await page.getByRole('button', { name: 'ログアウト' }).click();
      await expect(page).toHaveURL(/\/login/);
    });
  });
});
