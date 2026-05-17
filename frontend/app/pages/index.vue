<script setup>
import { CATEGORY_OPTIONS, useCategories } from "~/composables/useCategories.js"

const api = useApi()
const config = useRuntimeConfig()
const route = useRoute()
const router = useRouter()
const { labelOf, iconOf, gradientOf } = useCategories()

// URL クエリと双方向同期 (リロード/共有可)
const q        = ref(route.query.q || "")
const category = ref(route.query.category || "")
const sort     = ref(route.query.sort || "recent")
// F-FOLLOW-04: タイムラインタブ ("all" or "following")
const feed     = ref(route.query.feed === "following" ? "following" : "all")

// 無限スクロール状態 (絞り込み変更で常にリセット)
const trips       = ref([])
const nextCursor  = ref(null)
const pending     = ref(false)
const error       = ref(null)
const loadingMore = ref(false)

// 絞り込み変更で「世代」を増やし、世代をまたいだ古いレスポンスは破棄する。
// (例: スクロール中にカテゴリ切替 → 古い loadMore のレスポンスが新リストに紛れる罠を防ぐ)
let loadGen = 0

function currentParams(cursor = null) {
  const p = { sort: sort.value }
  if (q.value) p.q = q.value
  if (category.value) p.category = category.value
  if (cursor) p.cursor = cursor
  if (feed.value === "following") p.mine = "following"
  return p
}

async function reload() {
  loadGen += 1
  const myGen = loadGen
  pending.value = true
  error.value = null
  try {
    const res = await api.get("/trips", { params: currentParams() })
    if (myGen !== loadGen) return  // 世代不一致 → 破棄
    trips.value      = res.trips
    nextCursor.value = res.next_cursor
  } catch (e) {
    if (myGen === loadGen) error.value = e
  } finally {
    if (myGen === loadGen) pending.value = false
  }
}

async function loadMore() {
  if (loadingMore.value || !nextCursor.value) return
  const myGen = loadGen
  loadingMore.value = true
  try {
    const res = await api.get("/trips", { params: currentParams(nextCursor.value) })
    if (myGen !== loadGen) return  // 絞り込み変更で世代が進んだ → 古い結果を捨てる
    trips.value.push(...res.trips)
    nextCursor.value = res.next_cursor
  } finally {
    loadingMore.value = false
  }
}

await reload()

// 人気タグは一度だけ取得
const { data: popularTags } = await useAsyncData("popular-tags", () =>
  api.get("/tags/popular", { params: { limit: 15 } }),
  { deep: true }
)

// 絞り込み変更で URL 同期 + データ再読込
watch([q, category, sort, feed], ([newQ, newCat, newSort, newFeed]) => {
  const query = { ...route.query }
  newQ      ? query.q        = newQ        : delete query.q
  newCat    ? query.category = newCat      : delete query.category
  newSort && newSort !== "recent" ? query.sort = newSort : delete query.sort
  newFeed === "following" ? query.feed = "following" : delete query.feed
  router.replace({ query })
  reload()
})

// URL → ref の逆方向同期: 外部リンク (右固定サイドナビ等) からの遷移で
// route.query は変わるが、setup 時に初期化した ref は自動更新されない。
// ここで明示同期することで「サイドナビ国内クリック → category ref が 'domestic' に更新
// → 既存 watch が reload を発火」の流れを成立させる。
// 同値代入は Vue ref がトリガーしないので無限ループの心配なし。
watch(() => route.query, (newQuery) => {
  q.value        = newQuery.q || ""
  category.value = newQuery.category || ""
  sort.value     = newQuery.sort || "recent"
  feed.value     = newQuery.feed === "following" ? "following" : "all"
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

// 案 A: ヒーロー Top 3 (絞り込み無し時のみ・1 大 + 2 小 Bento)
const featuredTrips = computed(() => {
  if (q.value || category.value || feed.value !== "all") return []
  return [...trips.value]
    .sort((a, b) => (b.likes_count || 0) - (a.likes_count || 0))
    .slice(0, 3)
})
const heroTrip   = computed(() => featuredTrips.value[0] || null)
const subHero1   = computed(() => featuredTrips.value[1] || null)
const subHero2   = computed(() => featuredTrips.value[2] || null)
const heroIds    = computed(() => new Set(featuredTrips.value.map(t => t.id)))

// 絞り込み無し時のみ、ヒーロー以外を「人気」(rank 4-9) と「最近」(残り) に分割表示
const sectionedView = computed(() => !q.value && !category.value && feed.value === "all" && heroTrip.value)
const popularBatch = computed(() => {
  if (!sectionedView.value) return []
  return [...trips.value]
    .filter(t => !heroIds.value.has(t.id))
    .sort((a, b) => (b.likes_count || 0) - (a.likes_count || 0))
    .slice(0, 6)
})
const popularBatchIds = computed(() => new Set(popularBatch.value.map(t => t.id)))
const recentBatch = computed(() => {
  if (!sectionedView.value) return trips.value.filter(t => !heroIds.value.has(t.id))
  return trips.value.filter(t => !heroIds.value.has(t.id) && !popularBatchIds.value.has(t.id))
})

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}

// 画像未アップロード時のフォールバック (Picsum: trip.id をシードに deterministic)
// 将来的に Active Storage 経由で実画像 attach する想定だが、デモ用見栄え向上に
function tripImage(trip, w = 800, h = 450) {
  if (trip.image_url) return fullImageUrl(trip.image_url)
  return `https://picsum.photos/seed/trip-${trip.id}/${w}/${h}`
}

function formatRange(s, e) {
  return `${s} 〜 ${e}`
}
</script>

<style scoped>
/* 画像の fade-in (load 完了で opacity 0 → 1) */
.trip-img { opacity: 0; transition: opacity 350ms ease; }
.trip-img.loaded { opacity: 1; }

/* カードの初期描画 fade + 持ち上がり */
@keyframes card-rise {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.trip-card { animation: card-rise 350ms ease both; }
</style>

<template>
  <div>
    <!-- 案 A+: Bento ヒーロー (Top 3) - 1 大 + 2 小 -->
    <section v-if="heroTrip" class="mb-6 grid grid-cols-1 md:grid-cols-3 gap-3">
      <!-- メインヒーロー (左 2/3) -->
      <NuxtLink :to="`/trips/${heroTrip.id}`" class="md:col-span-2 group relative overflow-hidden rounded-2xl shadow-lg block">
        <div :class="['relative aspect-[16/9] md:aspect-[2/1] bg-gradient-to-br', gradientOf(heroTrip.category)]">
          <img :src="tripImage(heroTrip, 1200, 600)" :alt="heroTrip.title" class="trip-img absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105" loading="eager" @load="$event.target.classList.add('loaded')" />
          <div class="absolute inset-0 bg-gradient-to-t from-black/75 via-black/20 to-transparent"></div>
          <div class="absolute top-4 left-4 inline-flex items-center gap-1 px-2.5 py-1 bg-white/95 dark:bg-slate-900/85 rounded-full text-xs font-medium text-slate-700 dark:text-slate-200 backdrop-blur-sm">
            <span>✨</span><span>今週の 1 位</span>
          </div>
          <div class="absolute bottom-0 left-0 right-0 p-5 md:p-6 text-white">
            <div class="flex items-center gap-2 text-sm opacity-90 mb-1">
              <span>{{ iconOf(heroTrip.category) }}</span><span>{{ labelOf(heroTrip.category) }}</span>
              <span>·</span><span>{{ heroTrip.destination }}</span>
            </div>
            <h2 class="text-2xl md:text-3xl font-bold leading-tight group-hover:underline drop-shadow">{{ heroTrip.title }}</h2>
            <div class="mt-2 flex items-center gap-4 text-sm opacity-90">
              <span>@{{ heroTrip.user.display_name }}</span>
              <span>♡ {{ heroTrip.likes_count }}</span>
              <span>💬 {{ heroTrip.comments_count }}</span>
            </div>
          </div>
        </div>
      </NuxtLink>

      <!-- サブヒーロー 2 枚 (右 1/3, 縦並び) -->
      <div class="grid grid-rows-2 gap-3">
        <NuxtLink
          v-for="(sub, idx) in [subHero1, subHero2]"
          :key="sub?.id || idx"
          v-show="sub"
          :to="sub ? `/trips/${sub.id}` : '#'"
          class="group relative overflow-hidden rounded-2xl shadow-md block"
        >
          <div v-if="sub" :class="['relative h-full min-h-[120px] bg-gradient-to-br', gradientOf(sub.category)]">
            <img :src="tripImage(sub, 600, 400)" :alt="sub.title" class="trip-img absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105" loading="eager" @load="$event.target.classList.add('loaded')" />
            <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/10 to-transparent"></div>
            <div class="absolute top-2 left-2 inline-flex items-center gap-1 px-2 py-0.5 bg-white/90 dark:bg-slate-900/80 rounded-full text-[10px] font-medium text-slate-700 dark:text-slate-200">
              <span>{{ idx === 0 ? '🥈' : '🥉' }}</span><span>{{ idx === 0 ? '2 位' : '3 位' }}</span>
            </div>
            <div class="absolute bottom-0 left-0 right-0 p-3 text-white">
              <div class="text-[10px] opacity-90 mb-0.5">{{ iconOf(sub.category) }} {{ sub.destination }}</div>
              <h3 class="text-sm font-bold leading-tight line-clamp-2 group-hover:underline drop-shadow">{{ sub.title }}</h3>
              <div class="mt-1 flex items-center gap-3 text-[10px] opacity-90">
                <span>♡ {{ sub.likes_count }}</span>
                <span>💬 {{ sub.comments_count }}</span>
              </div>
            </div>
          </div>
        </NuxtLink>
      </div>
    </section>

    <!-- F-FOLLOW-04: タイムラインタブ -->
    <div class="flex gap-1 mb-4 border-b border-slate-200 dark:border-slate-700">
      <button
        type="button" @click="feed = 'all'"
        :class="[
          'px-4 py-2 text-sm border-b-2 -mb-px',
          feed === 'all' ? 'border-brand-500 text-brand-600 dark:text-brand-50 font-bold' : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
        ]"
      >すべて</button>
      <button
        type="button" @click="feed = 'following'"
        :class="[
          'px-4 py-2 text-sm border-b-2 -mb-px',
          feed === 'following' ? 'border-brand-500 text-brand-600 dark:text-brand-50 font-bold' : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
        ]"
      >フォロー中</button>
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
          'text-xs px-3 py-1.5 rounded-full border inline-flex items-center gap-1.5',
          category === opt.value ? 'bg-brand-500 text-white border-brand-500' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700'
        ]"
      ><span>{{ opt.icon }}</span><span>{{ opt.label }}</span></button>
    </div>

    <!-- 装飾見出し: 人気タグ -->
    <div v-if="popularTags && popularTags.length" class="flex items-center gap-3 mb-3 mt-2">
      <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700"></span>
      <span class="text-xs tracking-[0.3em] text-slate-400 dark:text-slate-500 inline-flex items-center gap-1.5"><span>🏷️</span><span>POPULAR TAGS</span></span>
      <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700"></span>
    </div>
    <section v-if="popularTags && popularTags.length" class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-4 mb-6">
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

    <!-- 装飾見出し: ⚡ 人気の旅 (sectionedView 時のみ) -->
    <template v-if="sectionedView && popularBatch.length">
      <div class="flex items-center gap-3 mb-4 mt-2">
        <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700"></span>
        <span class="text-xs tracking-[0.3em] text-slate-400 dark:text-slate-500 inline-flex items-center gap-1.5"><span>⚡</span><span>POPULAR TRIPS</span></span>
        <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700"></span>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <NuxtLink
          v-for="trip in popularBatch"
          :key="`pop-${trip.id}`"
          :to="`/trips/${trip.id}`"
          class="trip-card group bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden hover:shadow-xl hover:-translate-y-1 transition-all duration-200 flex flex-col relative"
        >
          <div :class="['absolute top-3 -left-8 z-10 px-9 py-1 -rotate-45 text-[10px] tracking-widest font-bold text-white shadow-lg ring-1 ring-white/40 bg-gradient-to-r', gradientOf(trip.category)]">
            {{ labelOf(trip.category) }}
          </div>
          <div :class="['aspect-video relative overflow-hidden bg-gradient-to-br', gradientOf(trip.category)]">
            <img :src="tripImage(trip, 600, 400)" class="trip-img absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" :alt="trip.title" loading="lazy" @load="$event.target.classList.add('loaded')" />
            <!-- 下部から立ち上がる暗グラデで「行き先」を確実に読ませる -->
            <div class="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-black/60 via-black/20 to-transparent"></div>
            <span class="absolute bottom-2 right-3 text-white text-xs font-bold drop-shadow-lg z-10">📍 {{ trip.destination }}</span>
          </div>
          <div class="p-4 flex-1 flex flex-col">
            <h3 class="font-bold text-slate-800 dark:text-slate-100 line-clamp-1">{{ trip.title }}</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ formatRange(trip.started_on, trip.ended_on) }} / {{ trip.destination }}</p>
            <p class="text-xs text-slate-600 dark:text-slate-300 mt-1">@{{ trip.user.display_name }}</p>
            <div v-if="(trip.tags || []).length" class="mt-2 flex flex-wrap gap-1">
              <span v-for="name in (trip.tags || []).slice(0, 3)" :key="name" class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">#{{ name }}</span>
            </div>
            <div class="mt-auto pt-3 flex items-center gap-4 text-sm text-slate-500 dark:text-slate-400">
              <span>♡ {{ trip.likes_count }}</span>
              <span>💬 {{ trip.comments_count }}</span>
            </div>
          </div>
        </NuxtLink>
      </div>
    </template>

    <!-- 装飾見出し: 🕘 最近の旅 (or 検索/絞り込み時は TRAVEL LOGS) -->
    <div class="flex items-center gap-3 mb-4 mt-2">
      <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700"></span>
      <span class="text-xs tracking-[0.3em] text-slate-400 dark:text-slate-500 inline-flex items-center gap-1.5">
        <span>{{ sectionedView ? '🕘' : '📖' }}</span>
        <span>{{ sectionedView ? 'RECENT TRIPS' : 'TRAVEL LOGS' }}</span>
      </span>
      <span class="h-px flex-1 bg-slate-200 dark:bg-slate-700"></span>
    </div>

    <div v-if="pending" class="text-center py-12 text-slate-500 dark:text-slate-400">読み込み中…</div>
    <div v-else-if="error" class="text-center py-12 text-rose-600">エラー: {{ error.message }}</div>
    <div v-else-if="trips.length === 0" class="bg-white dark:bg-slate-800 rounded-lg p-8 text-center border border-slate-200 dark:border-slate-700">
      <p class="text-slate-500 dark:text-slate-400 mb-4">該当する旅行記録がありません。</p>
      <NuxtLink to="/trips/new" class="inline-block bg-brand-500 text-white px-4 py-2 rounded">+ 新しい旅行記録</NuxtLink>
    </div>

    <template v-else>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NuxtLink
          v-for="trip in recentBatch"
          :key="trip.id"
          :to="`/trips/${trip.id}`"
          class="trip-card group bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden hover:shadow-xl hover:-translate-y-1 transition-all duration-200 flex flex-col relative"
        >
          <div :class="['absolute top-3 -left-8 z-10 px-9 py-1 -rotate-45 text-[10px] tracking-widest font-bold text-white shadow-lg ring-1 ring-white/40 bg-gradient-to-r', gradientOf(trip.category)]">
            {{ labelOf(trip.category) }}
          </div>
          <div :class="['aspect-video relative overflow-hidden bg-gradient-to-br', gradientOf(trip.category)]">
            <img :src="tripImage(trip, 600, 400)" class="trip-img absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" :alt="trip.title" loading="lazy" @load="$event.target.classList.add('loaded')" />
            <!-- 下部から立ち上がる暗グラデで「行き先」を確実に読ませる -->
            <div class="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-black/60 via-black/20 to-transparent"></div>
            <span class="absolute bottom-2 right-3 text-white text-xs font-bold drop-shadow-lg z-10">📍 {{ trip.destination }}</span>
          </div>
          <div class="p-4 flex-1 flex flex-col">
            <h3 class="font-bold text-slate-800 dark:text-slate-100 line-clamp-1">{{ trip.title }}</h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ formatRange(trip.started_on, trip.ended_on) }} / {{ trip.destination }}</p>
            <p class="text-xs text-slate-600 dark:text-slate-300 mt-1">@{{ trip.user.display_name }}</p>
            <div v-if="(trip.tags || []).length" class="mt-2 flex flex-wrap gap-1">
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
