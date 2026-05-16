import { describe, it, expect, vi, beforeEach } from "vitest"
import { setActivePinia, createPinia } from "pinia"
import { useAuthStore } from "~/composables/useAuthStore.js"

describe("useAuthStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it("login() sets state.user from API response", async () => {
    const fakeUser = { id: 1, email: "alice@example.com", display_name: "Alice" }
    globalThis.useApi = () => ({
      post: vi.fn().mockResolvedValue({ user: fakeUser })
    })

    const auth = useAuthStore()
    await auth.login("alice@example.com", "password123")

    expect(auth.user).toEqual(fakeUser)
    expect(auth.fetched).toBe(true)
  })
})
