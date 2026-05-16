import { useAuthStore } from "~/composables/useAuthStore.js"

export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server) return
  const auth = useAuthStore()
  if (!auth.fetched) await auth.fetchMe()
  if (!auth.user) {
    return navigateTo({ path: "/login", query: { redirect: to.fullPath } })
  }
})
