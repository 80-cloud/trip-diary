<script setup>
import { CATEGORY_OPTIONS, useCategories } from "~/composables/useCategories.js"

const api = useApi()
const config = useRuntimeConfig()
const route = useRoute()
const router = useRouter()
const { labelOf } = useCategories()

// URL クエリと双方向同期 (リロード/共有可)
const q        = ref(route.query.q || "")
const category = ref(route.query.category || "")
const sort     = ref(route.query.sort || "recent")

// 無限スクロール状態 (絞り込み変更で常にリセット)
const trips       = ref([])
const nextCursor  = ref(null)
const pending     = ref(false)
const error       = ref(null)
const loadingMore = ref(false)

function currentParams(cursor = null) {
  const p = { sort: sort.value }
  if (q.value) p.q = q.value
  if (category.value) p.category = category.value
  if (cursor) p.cursor = cursor
  return p
}

async function reload() {
  pending.value = true
  error.value = null
  try {
    const res = await api.get("/trips", { params: currentParams() })
    trips.value      = res.trips
    nextCursor.value = res.next_cursor
  } catch (e) {
    error.value = e
  } finally {
    pending.value = false
  }
}

async function loadMore() {
  if (loadingMore.value || !nextCursor.value) return
  loadingMore.value = true
  try {
    const res = await api.get("/trips", { params: currentParams(nextCursor.value) })
    trips.value.push(...res.trips)
    nextCursor.value = res.next_cursor
  } finally {
    loadingMore.value = false
  }
}

await reload()

// 人気タグは一度だけ取得
const { data: popularTags } = await useAsyncData("popular-tags", () =>
  api.get("/tags/popular", { params: { limit: 15 } })
)

// 絞り込み変更で URL 同期 + データ再読込
watch([q, category, sort], ([newQ, newCat, newSort]) => {
  const query = { ...route.query }
  newQ      ? query.q        = newQ        : delete query.q
  newCat    ? query.category = newCat      : delete query.category
  newSort && newSort !== "recent" ? query.sort = newSort : delete query.sort
  router.replace({ query })
  reload()
})

// F-UX-INF-SCROLL: sentinel の IntersectionObserver で末尾検知 → loadMore
const sentinel = ref(null)
let observer = null
onMounted(() => {
  if (typeof IntersectionObserver === "undefined") return
  observer = new IntersectionObserver(
    (entries) => {
      if (entries[0].isIntersecting) loadMore()
    },
    { rootMargin: "200px" } // 200px 手前で先回り fetch
  )
  if (sentinel.value) observer.observe(sentinel.value)
})
onBeforeUnmount(() => {
  if (observer) observer.disconnect()
})
// sentinel は v-if 制御で出現するため再 observe が必要
watch(sentinel, (el) => {
  if (observer && el) observer.observe(el)
})

function selectCategory(value) {
  category.value = category.value === value ? "" : value
}

function tagSize(count, max) {
  if (!max || max <= 1) return 14
  return 12 + Math.round((count / max) * 12)
}

const maxTagCount = computed(() => {
  if (!popularTags.value || popularTags.value.length === 0) return 1
  return popularTags.value[0].trips_count || 1
})

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}

function formatRange(s, e) {
  return `${s} 〜 ${e}`
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-4">
      <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100">タイムライン</h1>
    </div>

    <!-- 検索 + ソート -->
    <div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-4 mb-4 flex flex-col md:flex-row md:items-center gap-3">
      <input
        v-model.lazy="q"
        type="search" maxlength="80"
        placeholder="タイトル / 場所 / タグで検索"
        class="flex-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-2 text-sm"
      />
      <select v-model="sort" class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-2 text-sm">
        <option value="recent">新着順</option>
        <option value="popular">人気順 (いいね数)</option>
        <option value="title">タイトル順</option>
      </select>
    </div>

    <!-- カテゴリタブ -->
    <div class="flex flex-wrap gap-2 mb-4">
      <button
        type="button"
        @click="category = ''"
        :class="[
          'text-xs px-3 py-1.5 rounded-full border',
          category === '' ? 'bg-brand-500 text-white border-brand-500' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700'
        ]"
      >すべて</button>
      <button
        v-for="opt in CATEGORY_OPTIONS"
        :key="opt.value"
        type="button"
        @click="selectCategory(opt.value)"
        :class="[
          'text-xs px-3 py-1.5 rounded-full border',
          category === opt.value ? 'bg-brand-500 text-white border-brand-500' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700'
        ]"
      >{{ opt.label }}</button>
    </div>

    <!-- 人気タグクラウド -->
    <section v-if="popularTags && popularTags.length" class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-4 mb-4">
      <h2 class="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">人気タグ</h2>
      <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <NuxtLink
          v-for="t in popularTags"
          :key="t.id"
          :to="`/tags/${encodeURIComponent(t.name)}`"
          class="text-brand-600 dark:text-brand-50 hover:underline"
          :style="{ fontSize: `${tagSize(t.trips_count, maxTagCount)}px` }"
        >#{{ t.name }} <span class="text-slate-400 dark:text-slate-500 text-xs">({{ t.trips_count }})</span></NuxtLink>
      </div>
    </section>

    <div v-if="pending" class="text-center py-12 text-slate-500 dark:text-slate-400">読み込み中…</div>
    <div v-else-if="error" class="text-center py-12 text-rose-600">エラー: {{ error.message }}</div>
    <div v-else-if="trips.length === 0" class="bg-white dark:bg-slate-800 rounded-lg p-8 text-center border border-slate-200 dark:border-slate-700">
      <p class="text-slate-500 dark:text-slate-400 mb-4">該当する旅行記録がありません。</p>
      <NuxtLink to="/trips/new" class="inline-block bg-brand-500 text-white px-4 py-2 rounded">+ 新しい旅行記録</NuxtLink>
    </div>

    <template v-else>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NuxtLink
          v-for="trip in trips"
          :key="trip.id"
          :to="`/trips/${trip.id}`"
          class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden hover:shadow-md transition-shadow flex flex-col"
        >
          <div class="aspect-video bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-300 dark:text-slate-500">
            <img v-if="trip.image_url" :src="fullImageUrl(trip.image_url)" class="w-full h-full object-cover" :alt="trip.title" />
            <span v-else class="text-4xl">📷</span>
          </div>
          <div class="p-4 flex-1 flex flex-col">
            <h3 class="font-bold text-slate-800 dark:text-slate-100 line-clamp-1">{{ trip.title }}</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ formatRange(trip.started_on, trip.ended_on) }} / {{ trip.destination }}</p>
            <p class="text-xs text-slate-600 dark:text-slate-300 mt-1">@{{ trip.user.display_name }}</p>
            <div class="mt-2 flex flex-wrap gap-1">
              <span class="text-[10px] px-1.5 py-0.5 rounded bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50">{{ labelOf(trip.category) }}</span>
              <span v-for="name in (trip.tags || []).slice(0, 3)" :key="name" class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">#{{ name }}</span>
            </div>
            <div class="mt-auto pt-3 flex items-center gap-4 text-sm text-slate-500 dark:text-slate-400">
              <span>♡ {{ trip.likes_count }}</span>
              <span>💬 {{ trip.comments_count }}</span>
            </div>
          </div>
        </NuxtLink>
      </div>

      <!-- 無限スクロール sentinel: next_cursor がある間だけ DOM に出す -->
      <div v-if="nextCursor" ref="sentinel" class="h-10 mt-4 flex items-center justify-center text-xs text-slate-400 dark:text-slate-500">
        {{ loadingMore ? "読み込み中…" : "次を読み込み中…" }}
      </div>
      <div v-else class="text-center mt-6 text-xs text-slate-400 dark:text-slate-500">— ここまで —</div>
    </template>
  </div>
</template>
