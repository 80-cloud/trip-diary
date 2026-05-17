// @ts-check
import withNuxt from "./.nuxt/eslint.config.mjs"

export default withNuxt({
  rules: {
    // Vue 3 はフラグメント (複数 root) を公式サポート。
    // vue/no-multiple-template-root は Vue 2 互換ルールなので無効化。
    "vue/no-multiple-template-root": "off",

    // _foo / _e の prefix で「意図的に未使用」を明示する標準慣習を許可。
    // catch 句の error 変数等で頻出。
    "no-unused-vars": ["error", {
      argsIgnorePattern: "^_",
      varsIgnorePattern: "^_",
      caughtErrorsIgnorePattern: "^_"
    }],
    "@typescript-eslint/no-unused-vars": ["error", {
      argsIgnorePattern: "^_",
      varsIgnorePattern: "^_",
      caughtErrorsIgnorePattern: "^_"
    }]
  }
})
