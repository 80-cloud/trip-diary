import { describe, it, expect, beforeEach } from "vitest"
import { setActivePinia, createPinia } from "pinia"
import { useNotificationsStore } from "~/composables/useNotificationsStore.js"

describe("useNotificationsStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    Object.values(globalThis.__apiMocks).forEach((m) => m.mockReset())
  })

  it("fetchUnreadCount() は API から unread_count を取得して state に反映", async () => {
    globalThis.__apiMocks.get.mockResolvedValue({ unread_count: 5 })
    const store = useNotificationsStore()
    await store.fetchUnreadCount()
    expect(store.unreadCount).toBe(5)
    expect(globalThis.__apiMocks.get).toHaveBeenCalledWith("/notifications/unread_count")
  })

  it("fetchUnreadCount() は API 失敗時 silently 0 を維持", async () => {
    globalThis.__apiMocks.get.mockRejectedValue(new Error("401"))
    const store = useNotificationsStore()
    store.unreadCount = 3 // 既存値
    await store.fetchUnreadCount()
    expect(store.unreadCount).toBe(0)
  })

  it("fetchList() は notifications と unread_count を取得し fetched フラグを立てる", async () => {
    const fakeList = [
      { id: 1, verb: "liked",     read_at: null, actor: { id: 2, display_name: "Bob" } },
      { id: 2, verb: "commented", read_at: "2026-05-17T12:00:00Z", actor: { id: 2, display_name: "Bob" } }
    ]
    globalThis.__apiMocks.get.mockResolvedValue({ notifications: fakeList, unread_count: 1 })
    const store = useNotificationsStore()
    await store.fetchList()
    expect(store.notifications).toEqual(fakeList)
    expect(store.unreadCount).toBe(1)
    expect(store.fetched).toBe(true)
    expect(store.loading).toBe(false)
  })

  it("markRead(id) は API 呼出し + 該当通知の read_at 更新 + unreadCount を -1", async () => {
    const store = useNotificationsStore()
    store.notifications = [
      { id: 1, verb: "liked", read_at: null, actor: { id: 2, display_name: "Bob" } },
      { id: 2, verb: "commented", read_at: null, actor: { id: 2, display_name: "Bob" } }
    ]
    store.unreadCount = 2
    globalThis.__apiMocks.patch.mockResolvedValue({ id: 1, read_at: "2026-05-17T13:00:00Z" })

    await store.markRead(1)
    expect(store.notifications[0].read_at).toBe("2026-05-17T13:00:00Z")
    expect(store.notifications[1].read_at).toBeNull()
    expect(store.unreadCount).toBe(1)
    expect(globalThis.__apiMocks.patch).toHaveBeenCalledWith("/notifications/1")
  })

  it("markRead(id) は既読の通知に対しては unreadCount を下げない (二重既読防御)", async () => {
    const store = useNotificationsStore()
    store.notifications = [
      { id: 1, verb: "liked", read_at: "2026-05-17T12:00:00Z", actor: { id: 2, display_name: "Bob" } }
    ]
    store.unreadCount = 3
    globalThis.__apiMocks.patch.mockResolvedValue({ id: 1, read_at: "2026-05-17T12:00:00Z" })

    await store.markRead(1)
    expect(store.unreadCount).toBe(3) // 変わらず
  })

  it("markAllRead() は API 呼出し + 全通知に read_at を付与 + unreadCount=0", async () => {
    const store = useNotificationsStore()
    store.notifications = [
      { id: 1, verb: "liked",     read_at: null,                       actor: { id: 2, display_name: "Bob" } },
      { id: 2, verb: "commented", read_at: "2026-05-17T11:00:00Z",     actor: { id: 2, display_name: "Bob" } }
    ]
    store.unreadCount = 1
    globalThis.__apiMocks.post.mockResolvedValue({ read_count: 1, unread_count: 0 })

    await store.markAllRead()
    expect(store.notifications[0].read_at).not.toBeNull() // 既読化された
    expect(store.notifications[1].read_at).toBe("2026-05-17T11:00:00Z") // 元の既読時刻は保持
    expect(store.unreadCount).toBe(0)
    expect(globalThis.__apiMocks.post).toHaveBeenCalledWith("/notifications/read_all")
  })

  it("reset() で state が初期化される (logout 用)", () => {
    const store = useNotificationsStore()
    store.notifications = [{ id: 1 }]
    store.unreadCount = 5
    store.fetched = true
    store.reset()
    expect(store.notifications).toEqual([])
    expect(store.unreadCount).toBe(0)
    expect(store.fetched).toBe(false)
  })
})
