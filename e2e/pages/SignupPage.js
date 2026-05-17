// SignupPage Page Object。frontend/app/pages/signup.vue に対応。
// フィールド順: 表示名 (text) / メールアドレス (email) / パスワード (password)。
// label と input が for/id で紐付いていないため、type 属性 + 順序で locate する。

export class SignupPage {
  constructor(page) {
    this.page = page;
    this.displayNameInput = page.locator('input[type="text"]').first();
    this.emailInput = page.locator('input[type="email"]');
    this.passwordInput = page.locator('input[type="password"]');
    this.submitButton = page.getByRole('button', { name: /登録する|登録中/ });
  }

  async goto() {
    await this.page.goto('/signup');
  }

  async signup({ email, displayName, password }) {
    await this.displayNameInput.fill(displayName);
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
