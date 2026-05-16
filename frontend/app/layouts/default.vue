<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"

const auth = useAuthStore()
const router = useRouter()

onMounted(() => {
  if (!auth.fetched) auth.fetchMe()
})

async function logout() {
  await auth.logout()
  router.push("/login")
}
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <header class="bg-white border-b border-slate-200 sticky top-0 z-10">
      <div class="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between">
        <NuxtLink to="/" class="text-xl font-bold text-brand-600 flex items-center gap-2">
          <span>✈️</span>
          <span>trip-diary</span>
        </NuxtLink>
        <nav class="flex items-center gap-3">
          <template v-if="auth.user">
            <NuxtLink
              to="/trips/new"
              class="bg-brand-500 text-white px-3 py-1.5 rounded text-sm font-medium hover:bg-brand-600"
            >
              + 新しい旅行記録
            </NuxtLink>
            <span class="text-sm text-slate-600">@{{ auth.user.display_name }}</span>
            <button
              @click="logout"
              class="text-sm text-slate-500 hover:text-slate-800 underline"
            >
              ログアウト
            </button>
          </template>
          <template v-else-if="auth.fetched">
            <NuxtLink to="/login" class="text-sm text-slate-700 hover:underline">ログイン</NuxtLink>
            <NuxtLink to="/signup" class="text-sm bg-brand-500 text-white px-3 py-1.5 rounded">
              サインアップ
            </NuxtLink>
          </template>
          <template v-else>
            <span class="text-xs text-slate-400">読み込み中…</span>
          </template>
        </nav>
      </div>
    </header>

    <main class="max-w-5xl mx-auto px-4 py-6">
      <slot />
    </main>

    <footer class="border-t border-slate-200 mt-12 py-6 text-center text-xs text-slate-500">
      © 2026 trip-diary —
      <a href="https://github.com/80-cloud/trip-diary" target="_blank" rel="noopener" class="underline">
        GitHub
      </a>
    </footer>
  </div>
</template>
