import { describe, it, expect, beforeEach } from "vitest"
import { setActivePinia, createPinia } from "pinia"
import { useAuthStore } from "~/composables/useAuthStore.js"

describe("useAuthStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    // 共有 mock を毎テストで初期化 (setup.js の __apiMocks を参照)
    Object.values(globalThis.__apiMocks).forEach((m) => m.mockReset())
  })

  it("login() sets state.user from API response and marks fetched", async () => {
    const fakeUser = { id: 1, email: "alice@example.com", display_name: "Alice" }
    globalThis.__apiMocks.post.mockResolvedValue({ user: fakeUser })

    const auth = useAuthStore()
    await auth.login("alice@example.com", "password123")

    expect(auth.user).toEqual(fakeUser)
    expect(auth.fetched).toBe(true)
    expect(globalThis.__apiMocks.post).toHaveBeenCalledWith("/login", {
      body: { email: "alice@example.com", password: "password123" }
    })
  })
})
