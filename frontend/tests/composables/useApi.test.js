import { describe, it, expect, beforeEach } from "vitest"
import { setActivePinia, createPinia } from "pinia"
import { useApi } from "~/composables/useApi.js"
import { useAuthStore } from "~/composables/useAuthStore.js"
import { useNotificationsStore } from "~/composables/useNotificationsStore.js"

// ofetch の FetchError と同じく、HTTP ステータスを statusCode に持つエラーを作る
function httpError(status) {
  const error = new Error(`HTTP ${status}`)
  error.statusCode = status
  error.data = { error: "テスト用のエラー" }
  return error
}

describe("useApi", () => {
  let auth
  let notifications

  beforeEach(() => {
    setActivePinia(createPinia())
    globalThis.$fetch.mockReset()
    auth = useAuthStore()
    auth.user = { id: 1, display_name: "ゲスト-0001", guest: true }
    auth.fetched = true
    notifications = useNotificationsStore()
    notifications.unreadCount = 2
    notifications.notifications = [{ id: 1, verb: "liked", read_at: null }]
  })

  it("401 を受けたら、ログイン状態を空にし、fetched は true のまま", async () => {
    globalThis.$fetch.mockRejectedValue(httpError(401))
    await expect(useApi().post("/trips/1/like")).rejects.toThrow()
    expect(auth.user).toBeNull()
    expect(auth.fetched).toBe(true)
  })

  it("401 を受けたら、通知の件数と一覧を空にする", async () => {
    globalThis.$fetch.mockRejectedValue(httpError(401))
    await expect(useApi().get("/notifications")).rejects.toThrow()
    expect(notifications.unreadCount).toBe(0)
    expect(notifications.notifications).toEqual([])
  })

  it("401 のエラーを、そのまま呼び出し元へ投げ直す", async () => {
    const error = httpError(401)
    globalThis.$fetch.mockRejectedValue(error)
    await expect(useApi().del("/trips/1/like")).rejects.toBe(error)
  })

  it.each([403, 404, 422, 500])("%i のときは、ログイン状態と通知を変えない", async (status) => {
    globalThis.$fetch.mockRejectedValue(httpError(status))
    await expect(useApi().get("/trips/1")).rejects.toThrow()
    expect(auth.user).not.toBeNull()
    expect(notifications.unreadCount).toBe(2)
  })

  it("通信エラー (statusCode が無い) のときは、ログイン状態を変えない", async () => {
    globalThis.$fetch.mockRejectedValue(new TypeError("Failed to fetch"))
    await expect(useApi().get("/trips/1")).rejects.toThrow()
    expect(auth.user).not.toBeNull()
  })

  it("成功したときは、結果をそのまま返し、ログイン状態を変えない", async () => {
    globalThis.$fetch.mockResolvedValue({ likes_count: 4 })
    await expect(useApi().post("/trips/1/like")).resolves.toEqual({ likes_count: 4 })
    expect(auth.user).not.toBeNull()
  })
})
