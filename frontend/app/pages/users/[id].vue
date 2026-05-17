<script setup>
const route = useRoute()
const api = useApi()
const config = useRuntimeConfig()

const id = route.params.id
const tab = ref(route.query.tab === "followers" ? "followers" : "following")

const { data: list, refresh: refreshList } = await useAsyncData(
  () => `users-${id}-${tab.value}`,
  () => api.get(`/users/${id}/follows`, { params: { type: tab.value } }),
  { watch: [tab] }
)

const { data: tripsRes } = await useAsyncData(`users-${id}-trips`, () =>
  api.get("/trips", { params: { user_id: id, limit: 20 } })
)
const trips = computed(() => tripsRes.value?.trips || [])

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}

// このユーザー (= プロフィール対象) は trip のレスポンスから display_name を拾う
const profileName = computed(() => trips.value[0]?.user?.display_name || `User #${id}`)
</script>

<template>
  <div>
    <NuxtLink to="/" class="text-sm text-brand-600 dark:text-brand-50 hover:underline">← タイムラインに戻る</NuxtLink>
    <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100 mt-4 mb-2">@{{ profileName }}</h1>

    <!-- フォロー/フォロワータブ -->
    <div class="flex gap-1 mb-4 border-b border-slate-200 dark:border-slate-700">
      <button
        type="button" @click="tab = 'following'"
        :class="[
          'px-4 py-2 text-sm border-b-2 -mb-px',
          tab === 'following' ? 'border-brand-500 text-brand-600 dark:text-brand-50 font-bold' : 'border-transparent text-slate-500 dark:text-slate-400'
        ]"
      >フォロー中</button>
      <button
        type="button" @click="tab = 'followers'"
        :class="[
          'px-4 py-2 text-sm border-b-2 -mb-px',
          tab === 'followers' ? 'border-brand-500 text-brand-600 dark:text-brand-50 font-bold' : 'border-transparent text-slate-500 dark:text-slate-400'
        ]"
      >フォロワー</button>
    </div>

    <section class="mb-6">
      <ul v-if="list && list.length" class="divide-y divide-slate-200 dark:divide-slate-700 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700">
        <li v-for="u in list" :key="u.id" class="p-3 flex items-center justify-between">
          <NuxtLink :to="`/users/${u.id}`" class="text-sm text-slate-700 dark:text-slate-200 hover:underline">@{{ u.display_name }}</NuxtLink>
          <span v-if="u.followed_by_me" class="text-[10px] px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400">フォロー中</span>
        </li>
      </ul>
      <p v-else class="text-sm text-slate-500 dark:text-slate-400">{{ tab === "following" ? "フォロー中のユーザーはいません" : "フォロワーはいません" }}</p>
    </section>

    <h2 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3">投稿した旅行記録</h2>
    <div v-if="trips.length === 0" class="text-sm text-slate-500 dark:text-slate-400">公開された旅行記録はありません</div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <NuxtLink
        v-for="t in trips" :key="t.id" :to="`/trips/${t.id}`"
        class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden hover:shadow-md flex flex-col"
      >
        <div class="aspect-video bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-300 dark:text-slate-500">
          <img v-if="t.image_url" :src="fullImageUrl(t.image_url)" class="w-full h-full object-cover" :alt="t.title" />
          <span v-else class="text-4xl">📷</span>
        </div>
        <div class="p-4 flex-1">
          <h3 class="font-bold text-slate-800 dark:text-slate-100 line-clamp-1">{{ t.title }}</h3>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ t.started_on }} 〜 {{ t.ended_on }}</p>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
