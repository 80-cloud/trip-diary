// TripDetailPage Page Object。frontend/app/pages/trips/[id]/index.vue に対応。
// コメント投稿フォームは <input placeholder="コメントを書く (140 文字以内)"> + <button type="submit">投稿</button>。
// いいねボタンは <button @click="toggleLike"> 内に「♡|♥ N いいね」テキストを含む。

export class TripDetailPage {
  constructor(page) {
    this.page = page;
    this.title = page.locator('article h1').first();
    this.commentInput = page.getByPlaceholder(/コメントを書く/);
    this.commentSubmitButton = page.getByRole('button', { name: '投稿' });
    // いいね toggle ボタン。テキストに常に「いいね」を含むのでこれで安定。
    this.likeButton = page.getByRole('button', { name: /いいね/ });
    this.commentItems = page.locator('section:has(h2:text-matches("コメント")) ul li');
  }

  async gotoById(tripId) {
    await this.page.goto(`/trips/${tripId}`);
    await this.title.waitFor({ state: 'visible' });
  }

  async submitComment(body) {
    await this.commentInput.fill(body);
    await this.commentSubmitButton.click();
  }

  async clickLike() {
    await this.likeButton.click();
  }
}
