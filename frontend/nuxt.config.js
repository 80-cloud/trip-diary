export default defineNuxtConfig({
  compatibilityDate: "2026-04-01",
  devtools: { enabled: false },
  modules: ["@nuxtjs/tailwindcss", "@pinia/nuxt"],
  ssr: false,
  app: {
    head: {
      title: "旅行記録 — trip-diary",
      htmlAttrs: { lang: "ja" },
      meta: [
        { charset: "utf-8" },
        { name: "viewport", content: "width=device-width, initial-scale=1" }
      ]
    }
  },
  devServer: { port: 3011 },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || "http://localhost:3010/api/v1"
    }
  }
})
