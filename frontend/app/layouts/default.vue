<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"
import { useDarkMode } from "~/composables/useDarkMode.js"
import { useNotificationsStore } from "~/composables/useNotificationsStore.js"

const auth = useAuthStore()
const notifications = useNotificationsStore()
const router = useRouter()
const { isDark, toggle: toggleDark } = useDarkMode()

onMounted(() => {
  if (!auth.fetched) auth.fetchMe()
})

async function logout() {
  await auth.logout()
  notifications.reset()
  router.push("/login")
}

const route = useRoute()
// ヘッダの「+ 新しい旅行記録」リンク用 to。/trips/new に居る場合は ?fresh=<ts> を付けて
// 同一 path への navigation を発火させ、ページ側で TripForm を remount してフォームを
// リセットする (Nuxt の同一ルート抑止を回避)。
const newTripTo = computed(() => {
  if (route.path === "/trips/new") {
    return { path: "/trips/new", query: { fresh: String(Date.now()) } }
  }
  return "/trips/new"
})

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
            type="button"
            :aria-label="isDark ? 'ライトモードに切替' : 'ダークモードに切替'"
            :title="isDark ? 'ライトモードに切替 (屋外の光が強い時に推奨)' : 'ダークモードに切替'"
            class="w-10 h-10 flex items-center justify-center text-2xl rounded-full hover:bg-slate-100 dark:hover:bg-slate-700"
            @click="toggleDark"
          >{{ isDark ? "☀️" : "🌙" }}</button>
          <template v-if="auth.user">
            <NotificationsBell />
            <NuxtLink
              :to="newTripTo"
              class="bg-brand-500 text-white px-3 py-1.5 rounded text-sm font-medium hover:bg-brand-600"
            >+ 新しい旅行記録</NuxtLink>
            <NuxtLink to="/trips/drafts" class="text-sm text-slate-600 dark:text-slate-300 hover:underline">下書き</NuxtLink>
            <NuxtLink to="/favorites" class="text-sm text-slate-600 dark:text-slate-300 hover:underline">★</NuxtLink>
            <NuxtLink
              :to="`/users/${auth.user.id}`"
              class="flex items-center"
              :title="`@${auth.user.display_name}`"
              :aria-label="`@${auth.user.display_name} のプロフィール`"
            >
              <img
                v-if="auth.user.avatar_url"
                :src="fullImageUrl(auth.user.avatar_url)"
                :alt="auth.user.display_name"
                class="w-10 h-10 rounded-full object-cover"
              >
              <span
                v-else
                class="w-10 h-10 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center text-base"
              >👤</span>
            </NuxtLink>
            <button
              class="text-sm text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-100 underline"
              @click="logout"
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

    <!-- 右固定カテゴリショートカット (デスクトップのみ / lg 以上) -->
    <aside
      aria-label="カテゴリショートカット"
      class="hidden lg:flex fixed right-0 top-1/2 -translate-y-1/2 z-20 flex-col gap-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-l-2xl shadow-xl py-3 pl-1 pr-2"
    >
      <NuxtLink
        v-for="cat in [
          {label:'すべて',   icon:'🗺️', value:null},
          {label:'国内',     icon:'🏔️', value:'domestic'},
          {label:'海外',     icon:'✈️', value:'overseas'},
          {label:'一人旅',   icon:'🎒', value:'solo'},
          {label:'グルメ',   icon:'🍣', value:'gourmet'},
          {label:'世界遺産', icon:'🏛️', value:'heritage'},
          {label:'家族旅',   icon:'👨‍👩‍👧', value:'family'},
          {label:'アウトドア', icon:'🏕️', value:'outdoor'},
          {label:'出張',     icon:'💼', value:'business'}
        ]"
        :key="cat.label"
        :to="{ path: '/', query: cat.value ? { category: cat.value } : {} }"
        :title="cat.label"
        class="group w-14 h-14 flex flex-col items-center justify-center rounded-xl hover:bg-brand-500 hover:text-white transition"
      >
        <span class="text-xl">{{ cat.icon }}</span>
        <span class="text-[9px] mt-0.5 text-slate-600 dark:text-slate-300 group-hover:text-white tracking-tighter">{{ cat.label }}</span>
      </NuxtLink>
    </aside>

    <main class="max-w-5xl mx-auto px-4 py-6">
      <slot />
    </main>

    <footer class="border-t border-slate-200 dark:border-slate-700 mt-12 py-6 text-center text-xs text-slate-500 dark:text-slate-400">
      © 2026 trip-diary —
      <a href="https://github.com/80-cloud/trip-diary" target="_blank" rel="noopener" class="underline">GitHub</a>
    </footer>
  </div>
</template>
