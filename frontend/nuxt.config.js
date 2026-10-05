// 公開環境の URL (Issue #169)。画面はビルドのときに作るので、OGP の絶対 URL はビルドに焼き込まれる。
// URL が変わったらここを直す。画像は backend/public に置き、作り直すときはファイル名を変える (1 年キャッシュされるため)
const SITE_URL = "https://trip-diary-wpaf.onrender.com"
const DESCRIPTION = "登録なしで試せる旅行記録アプリ。旅の日記・写真・チケットを残し、コメントといいねで共有できます。"

export default defineNuxtConfig({
  compatibilityDate: "2026-04-01",
  devtools: { enabled: false },
  modules: ["@nuxtjs/tailwindcss", "@pinia/nuxt", "@nuxt/eslint"],
  ssr: false,
  app: {
    head: {
      title: "旅行記録 — trip-diary",
      htmlAttrs: { lang: "ja" },
      meta: [
        { charset: "utf-8" },
        { name: "viewport", content: "width=device-width, initial-scale=1" },
        { name: "description", content: DESCRIPTION },
        { property: "og:type", content: "website" },
        { property: "og:title", content: "旅行記録 — trip-diary" },
        { property: "og:description", content: DESCRIPTION },
        { property: "og:url", content: `${SITE_URL}/` },
        { property: "og:image", content: `${SITE_URL}/og.png` },
        { name: "twitter:card", content: "summary_large_image" }
      ]
    }
  },
  devServer: { port: 3011 },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || "http://localhost:3010/api/v1",
      // ビルド時に真偽値にする (未設定なら有効)。公開環境では "false" でビルドする
      signupEnabled: process.env.NUXT_PUBLIC_SIGNUP_ENABLED !== "false"
    }
  }
})
