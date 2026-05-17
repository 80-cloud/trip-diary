import { defineConfig } from "vitest/config"
import vue from "@vitejs/plugin-vue"
import { fileURLToPath } from "node:url"

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "~": fileURLToPath(new URL("./app", import.meta.url)),
      "@": fileURLToPath(new URL("./app", import.meta.url))
    }
  },
  test: {
    environment: "happy-dom",
    globals: true,
    setupFiles: ["./tests/setup.js"],
    include: ["tests/**/*.test.js"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      reportsDirectory: "./coverage",
      include: ["app/**/*.{js,vue}"],
      exclude: [
        "nuxt.config.js",
        "tailwind.config.js",
        "tests/**",
        ".nuxt/**",
        "node_modules/**",
        "app/**/*.d.ts"
      ],
      all: true,
      // 閾値は Phase 1 では 0% (生成確認のみ)。
      // PR #C のテスト計画書で段階目標 (Phase 2 ≥ 25% / Phase 3 ≥ 50%) を確定する。
      thresholds: { lines: 0, functions: 0, branches: 0, statements: 0 }
    }
  }
})
