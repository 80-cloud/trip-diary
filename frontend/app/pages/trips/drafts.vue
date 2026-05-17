<script setup>
import { useCategories } from "~/composables/useCategories.js"

definePageMeta({ middleware: "auth" })

const api = useApi()
const config = useRuntimeConfig()
const { labelOf } = useCategories()

const { data, pending, error } = await useAsyncData(
  "my-drafts",
  () => api.get("/trips", { params: { mine: "drafts" } }),
  { deep: true }
)

const drafts = computed(() => data.value?.trips || [])

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
    <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100 mt-4 mb-4">下書き一覧</h1>

    <div v-if="pending" class="text-center py-12 text-slate-500 dark:text-slate-400">読み込み中…</div>
    <div v-else-if="error" class="text-center py-12 text-rose-600">エラー: {{ error.message }}</div>
    <div v-else-if="drafts.length === 0" class="bg-white dark:bg-slate-800 rounded-lg p-8 text-center border border-slate-200 dark:border-slate-700">
      <p class="text-slate-500 dark:text-slate-400 mb-4">下書きはまだありません。</p>
      <NuxtLink to="/trips/new" class="inline-block bg-brand-500 text-white px-4 py-2 rounded">+ 新しい旅行記録</NuxtLink>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <NuxtLink
        v-for="trip in drafts"
        :key="trip.id"
        :to="`/trips/${trip.id}`"
        class="bg-white dark:bg-slate-800 rounded-lg border border-amber-300 dark:border-amber-700 overflow-hidden hover:shadow-md transition-shadow flex flex-col"
      >
        <div class="aspect-video bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-300 dark:text-slate-500">
          <img v-if="trip.image_url" :src="fullImageUrl(trip.image_url)" class="w-full h-full object-cover" :alt="trip.title" />
          <span v-else class="text-4xl">📷</span>
        </div>
        <div class="p-4 flex-1 flex flex-col">
          <div class="flex items-center gap-2">
            <span class="text-[10px] px-1.5 py-0.5 rounded bg-amber-100 dark:bg-amber-900 text-amber-700 dark:text-amber-200 font-bold">下書き</span>
            <span class="text-[10px] px-1.5 py-0.5 rounded bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50">{{ labelOf(trip.category) }}</span>
          </div>
          <h3 class="font-bold text-slate-800 dark:text-slate-100 line-clamp-1 mt-1">{{ trip.title }}</h3>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ trip.started_on }} 〜 {{ trip.ended_on }} / {{ trip.destination }}</p>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
