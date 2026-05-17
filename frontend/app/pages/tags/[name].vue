<script setup>
import { useCategories } from "~/composables/useCategories.js"

const api = useApi()
const config = useRuntimeConfig()
const route = useRoute()
const { labelOf } = useCategories()

const name = computed(() => decodeURIComponent(route.params.name))
const sort = ref(route.query.sort || "recent")

const { data, pending, error } = await useAsyncData(
  () => `tag:${name.value}:${sort.value}`,
  () => api.get(`/tags/${encodeURIComponent(name.value)}`, { params: { sort: sort.value } }),
  { watch: [name, sort] }
)

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}
</script>

<template>
  <div>
    <NuxtLink to="/" class="text-sm text-brand-600 dark:text-brand-50 hover:underline">← タイムラインに戻る</NuxtLink>

    <div v-if="pending" class="text-center py-12 text-slate-500 dark:text-slate-400">読み込み中…</div>
    <div v-else-if="error && error.statusCode === 404" class="bg-white dark:bg-slate-800 rounded-lg p-8 text-center border border-slate-200 dark:border-slate-700 mt-4">
      <p class="text-slate-500">「#{{ name }}」というタグは存在しません。</p>
    </div>
    <div v-else-if="error" class="text-center py-12 text-rose-600">エラー: {{ error.message }}</div>

    <template v-else-if="data">
      <header class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-6 my-4 flex items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-brand-700 dark:text-brand-50">#{{ data.tag.name }}</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">{{ data.tag.trips_count }} 件の旅行記録</p>
        </div>
        <select v-model="sort" class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-2 text-sm">
          <option value="recent">新着順</option>
          <option value="popular">人気順</option>
          <option value="title">タイトル順</option>
        </select>
      </header>

      <div v-if="data.trips.length === 0" class="bg-white dark:bg-slate-800 rounded-lg p-8 text-center border border-slate-200 dark:border-slate-700">
        <p class="text-slate-500">該当する旅行記録がありません (非公開かもしれません)。</p>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NuxtLink
          v-for="trip in data.trips"
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
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ trip.started_on }} 〜 {{ trip.ended_on }} / {{ trip.destination }}</p>
            <p class="text-xs text-slate-600 dark:text-slate-300 mt-1">@{{ trip.user.display_name }}</p>
            <div class="mt-2 flex flex-wrap gap-1">
              <span class="text-[10px] px-1.5 py-0.5 rounded bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50">{{ labelOf(trip.category) }}</span>
              <span v-for="tname in (trip.tags || []).slice(0, 3)" :key="tname" class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">#{{ tname }}</span>
            </div>
            <div class="mt-auto pt-3 flex items-center gap-4 text-sm text-slate-500 dark:text-slate-400">
              <span>♡ {{ trip.likes_count }}</span>
              <span>💬 {{ trip.comments_count }}</span>
            </div>
          </div>
        </NuxtLink>
      </div>
    </template>
  </div>
</template>
