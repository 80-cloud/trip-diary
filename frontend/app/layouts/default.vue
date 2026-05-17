<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"
import { useDarkMode } from "~/composables/useDarkMode.js"

const auth = useAuthStore()
const router = useRouter()
const { isDark, toggle: toggleDark } = useDarkMode()

onMounted(() => {
  if (!auth.fetched) auth.fetchMe()
})

async function logout() {
  await auth.logout()
  router.push("/login")
}

const config = useRuntimeConfig()
function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-slate-100">
    <header class="bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 sticky top-0 z-10">
      <div class="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between">
        <NuxtLink to="/" class="text-xl font-bold text-brand-600 dark:text-brand-50 flex items-center gap-2">
          <span>✈️</span>
          <span>trip-diary</span>
        </NuxtLink>
        <nav class="flex items-center gap-3">
          <button
            @click="toggleDark"
            type="button"
            :aria-label="isDark ? 'ライトモードに切替' : 'ダークモードに切替'"
            :title="isDark ? 'ライトモードに切替 (屋外の光が強い時に推奨)' : 'ダークモードに切替'"
            class="text-lg p-1 rounded hover:bg-slate-100 dark:hover:bg-slate-700"
          >{{ isDark ? "☀️" : "🌙" }}</button>
          <template v-if="auth.user">
            <NuxtLink
              to="/trips/new"
              class="bg-brand-500 text-white px-3 py-1.5 rounded text-sm font-medium hover:bg-brand-600"
            >+ 新しい旅行記録</NuxtLink>
            <NuxtLink to="/trips/drafts" class="text-sm text-slate-600 dark:text-slate-300 hover:underline">下書き</NuxtLink>
            <NuxtLink to="/favorites" class="text-sm text-slate-600 dark:text-slate-300 hover:underline">★</NuxtLink>
            <NuxtLink
              :to="`/users/${auth.user.id}`"
              class="text-sm text-slate-600 dark:text-slate-300 hover:underline flex items-center gap-1"
            >
              <img
                v-if="auth.user.avatar_url"
                :src="fullImageUrl(auth.user.avatar_url)"
                :alt="auth.user.display_name"
                class="w-6 h-6 rounded-full object-cover"
              />
              <span>@{{ auth.user.display_name }}</span>
            </NuxtLink>
            <button
              @click="logout"
              class="text-sm text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-100 underline"
            >ログアウト</button>
          </template>
          <template v-else-if="auth.fetched">
            <NuxtLink to="/login" class="text-sm text-slate-700 dark:text-slate-200 hover:underline">ログイン</NuxtLink>
            <NuxtLink to="/signup" class="text-sm bg-brand-500 text-white px-3 py-1.5 rounded">サインアップ</NuxtLink>
          </template>
          <template v-else>
            <span class="text-xs text-slate-400 dark:text-slate-500">読み込み中…</span>
          </template>
        </nav>
      </div>
    </header>

    <main class="max-w-5xl mx-auto px-4 py-6">
      <slot />
    </main>

    <footer class="border-t border-slate-200 dark:border-slate-700 mt-12 py-6 text-center text-xs text-slate-500 dark:text-slate-400">
      © 2026 trip-diary —
      <a href="https://github.com/80-cloud/trip-diary" target="_blank" rel="noopener" class="underline">GitHub</a>
    </footer>
  </div>
</template>
