import { useAuthStore } from "~/composables/useAuthStore.js"

export default defineNuxtPlugin(async () => {
  const auth = useAuthStore()
  await auth.fetchMe()
})
