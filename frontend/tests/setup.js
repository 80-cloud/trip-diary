import { vi } from "vitest"

// Nuxt の auto-import を tests でも使えるよう globalThis に流す。
//
// 注意: `useApi` は **共有の mock オブジェクト** を返すように固定している。
// 各テストでは下記のように `__apiMocks` 経由で戻り値を上書きすること。
// (新しい vi.fn() を毎回返す実装にすると `expect(api.post).toHaveBeenCalled()`
//  系の検証ができなくなる罠があるため。)
//
//   // 例: 各テストの先頭で
//   import { beforeEach } from "vitest"
//   beforeEach(() => {
//     Object.values(globalThis.__apiMocks).forEach((m) => m.mockReset())
//   })
//
//   // 例: 戻り値を仕込む
//   globalThis.__apiMocks.post.mockResolvedValue({ user: { id: 1, ... } })
//
//   // 例: 呼び出しを検証
//   expect(globalThis.__apiMocks.post).toHaveBeenCalledWith("/login", { body: {...} })

const apiMocks = {
  get: vi.fn(),
  post: vi.fn(),
  put: vi.fn(),
  patch: vi.fn(),
  del: vi.fn()
}

globalThis.__apiMocks = apiMocks
globalThis.useApi = () => apiMocks

globalThis.useRuntimeConfig = () => ({
  public: { apiBase: "http://localhost:3010/api/v1" }
})

globalThis.$fetch = vi.fn()
