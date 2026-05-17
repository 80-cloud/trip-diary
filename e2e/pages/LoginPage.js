// LoginPage Page Object。frontend/app/pages/login.vue に対応。
// 注: login.vue の input 群は <label> と <input> が for/id で紐付いていないため
// (CLAUDE.md §12 のフィードバック候補)、type 属性で locate する。

export class LoginPage {
  constructor(page) {
    this.page = page;
    this.emailInput = page.locator('input[type="email"]');
    this.passwordInput = page.locator('input[type="password"]');
    this.submitButton = page.getByRole('button', { name: /ログイン$|ログイン中/ });
    this.errorMessage = page.locator('p.text-rose-600').first();
  }

  async goto() {
    await this.page.goto('/login');
    // Nuxt SPA + Vite dev の cold start は初回モジュール transform に時間がかかるため
    // DOM が hydrate されて input が DOM に出現するまで明示的に待つ。
    await this.emailInput.waitFor({ state: 'visible', timeout: 30_000 });
  }

  async login(email, password) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectErrorVisible() {
    await this.errorMessage.waitFor({ state: 'visible' });
  }
}
