import { defineStore } from "pinia"

// F-NOTIF-01/02 通知センター
// マウント時は unread_count のみ取得 (軽い)。ドロップダウンを開いた時に
// fetchList() で notifications 配列を取得する設計 (転送量最小化)。
export const useNotificationsStore = defineStore("notifications", {
  state: () => ({
    notifications: [],
    unreadCount: 0,
    fetched: false,        // 一覧を一度でも取得したか
    loading: false
  }),
  actions: {
    async fetchUnreadCount() {
      const api = useApi()
      try {
        const data = await api.get("/notifications/unread_count")
        this.unreadCount = data.unread_count
      } catch (_e) {
        // 未ログイン (401) など — silently 0 のまま
        this.unreadCount = 0
      }
      return this.unreadCount
    },
    async fetchList() {
      this.loading = true
      const api = useApi()
      try {
        const data = await api.get("/notifications")
        this.notifications = data.notifications
        this.unreadCount = data.unread_count
        this.fetched = true
      } catch (_e) {
        this.notifications = []
      } finally {
        this.loading = false
      }
      return this.notifications
    },
    async markRead(id) {
      const api = useApi()
      const updated = await api.patch(`/notifications/${id}`)
      // ローカル state を更新 (バッジ即時反映 / 再 fetch 不要)
      const idx = this.notifications.findIndex((n) => n.id === id)
      if (idx >= 0 && this.notifications[idx].read_at == null) {
        this.notifications[idx] = { ...this.notifications[idx], read_at: updated.read_at }
        this.unreadCount = Math.max(0, this.unreadCount - 1)
      }
      return updated
    },
    async markAllRead() {
      const api = useApi()
      const data = await api.post("/notifications/read_all")
      const now = new Date().toISOString()
      this.notifications = this.notifications.map((n) =>
        n.read_at ? n : { ...n, read_at: now }
      )
      this.unreadCount = 0
      return data
    },
    reset() {
      this.notifications = []
      this.unreadCount = 0
      this.fetched = false
      this.loading = false
    }
  }
})
