import { defineStore } from "pinia"

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    fetched: false
  }),
  actions: {
    async fetchMe() {
      if (this.fetched) return this.user
      const api = useApi()
      try {
        const data = await api.get("/me")
        this.user = data.user
      } catch (e) {
        this.user = null
      } finally {
        this.fetched = true
      }
      return this.user
    },
    async login(email, password) {
      const api = useApi()
      const data = await api.post("/login", { body: { email, password } })
      this.user = data.user
      this.fetched = true
      return data.user
    },
    async signup(email, password, displayName) {
      const api = useApi()
      const data = await api.post("/signup", {
        body: { email, password, display_name: displayName }
      })
      this.user = data.user
      this.fetched = true
      return data.user
    },
    async logout() {
      const api = useApi()
      await api.del("/logout")
      this.user = null
    }
  }
})
