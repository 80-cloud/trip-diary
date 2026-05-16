import { vi } from "vitest"

// Nuxt の auto-import を tests でも使えるよう globalThis に流す。
// 各テストが必要に応じて vi.fn() の戻り値を上書きする (例: useApi)。
globalThis.useRuntimeConfig = () => ({
  public: { apiBase: "http://localhost:3010/api/v1" }
})

globalThis.$fetch = vi.fn()

globalThis.useApi = () => ({
  get: vi.fn(),
  post: vi.fn(),
  put: vi.fn(),
  patch: vi.fn(),
  del: vi.fn()
})
