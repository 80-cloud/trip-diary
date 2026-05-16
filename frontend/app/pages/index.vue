<script setup>
const api = useApi()
const config = useRuntimeConfig()

const { data: trips, refresh, pending, error } = await useAsyncData("trips", () => api.get("/trips"))

function formatRange(s, e) {
  return `${s} 〜 ${e}`
}

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-4">
      <h1 class="text-2xl font-bold text-slate-800">タイムライン</h1>
    </div>

    <div v-if="pending" class="text-center py-12 text-slate-500">読み込み中…</div>
    <div v-else-if="error" class="text-center py-12 text-rose-600">エラー: {{ error.message }}</div>
    <div v-else-if="trips && trips.length === 0" class="bg-white rounded-lg p-8 text-center border border-slate-200">
      <p class="text-slate-500 mb-4">まだ旅行記録がありません。最初の記録を残しましょう。</p>
      <NuxtLink to="/trips/new" class="inline-block bg-brand-500 text-white px-4 py-2 rounded">
        + 新しい旅行記録
      </NuxtLink>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <NuxtLink
        v-for="trip in trips"
        :key="trip.id"
        :to="`/trips/${trip.id}`"
        class="bg-white rounded-lg border border-slate-200 overflow-hidden hover:shadow-md transition-shadow flex flex-col"
      >
        <div class="aspect-video bg-slate-100 flex items-center justify-center text-slate-300">
          <img v-if="trip.image_url" :src="fullImageUrl(trip.image_url)" class="w-full h-full object-cover" :alt="trip.title" />
          <span v-else class="text-4xl">📷</span>
        </div>
        <div class="p-4 flex-1 flex flex-col">
          <h3 class="font-bold text-slate-800 line-clamp-1">{{ trip.title }}</h3>
          <p class="text-xs text-slate-500 mt-1">{{ formatRange(trip.started_on, trip.ended_on) }} / {{ trip.destination }}</p>
          <p class="text-xs text-slate-600 mt-1">@{{ trip.user.display_name }}</p>
          <div class="mt-auto pt-3 flex items-center gap-4 text-sm text-slate-500">
            <span>♡ {{ trip.likes_count }}</span>
            <span>💬 {{ trip.comments_count }}</span>
          </div>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
