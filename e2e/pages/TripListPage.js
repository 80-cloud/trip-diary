// TripListPage Page Object。frontend/app/pages/index.vue (タイムライン) に対応。
// trip カードは <NuxtLink to="/trips/{id}"> 形式で render される。
// ログアウトボタンは layouts/default.vue の Header にある。

export class TripListPage {
  constructor(page) {
    this.page = page;
    this.tripLinks = page.locator('a[href^="/trips/"]');
    // ヘッダー (default layout) のログアウトボタン
    this.logoutButton = page.getByRole('button', { name: 'ログアウト' });
    // ヘッダーの「+ 新しい旅行記録」リンク (ログイン中のみ表示)
    this.newTripLink = page.getByRole('link', { name: /新しい旅行記録/ });
  }

  async goto() {
    await this.page.goto('/');
    // SPA fetch が落ち着くまで待つ (タイムライン GET /api/v1/trips)
    await this.page.waitForLoadState('networkidle').catch(() => {});
  }

  /**
   * 指定 title を含む trip カード (NuxtLink) を返す。複数一致時は最初のもの。
   */
  cardByTitle(title) {
    return this.page.locator(`a[href^="/trips/"]`).filter({ hasText: title }).first();
  }

  async clickCardByTitle(title) {
    await this.cardByTitle(title).click();
  }
}
