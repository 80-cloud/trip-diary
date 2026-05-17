<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"
import { useCategories } from "~/composables/useCategories.js"

const route = useRoute()
const router = useRouter()
const api = useApi()
const auth = useAuthStore()
const config = useRuntimeConfig()
const { labelOf } = useCategories()
const id = route.params.id

const { data: trip, refresh, pending, error } = await useAsyncData(`trip-${id}`, () => api.get(`/trips/${id}`))

const newComment = ref("")
const submitting = ref(false)
const actionError = ref(null)

function isOwner() {
  return auth.user && trip.value && trip.value.user.id === auth.user.id
}

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}

async function toggleLike() {
  if (!auth.user) {
    router.push({ path: "/login", query: { redirect: route.fullPath } })
    return
  }
  actionError.value = null
  try {
    if (trip.value.liked_by_me) {
      const res = await api.del(`/trips/${id}/like`)
      trip.value.liked_by_me = false
      trip.value.likes_count = res.likes_count
    } else {
      const res = await api.post(`/trips/${id}/like`)
      trip.value.liked_by_me = true
      trip.value.likes_count = res.likes_count
    }
  } catch (e) {
    actionError.value = e.data?.error || "操作に失敗しました"
  }
}

async function submitComment() {
  if (!auth.user) {
    router.push({ path: "/login", query: { redirect: route.fullPath } })
    return
  }
  submitting.value = true
  try {
    const c = await api.post(`/trips/${id}/comments`, { body: { body: newComment.value } })
    trip.value.comments.push(c)
    trip.value.comments_count += 1
    newComment.value = ""
  } catch (e) {
    actionError.value = e.data?.errors?.join(", ") || "コメント投稿に失敗しました"
  } finally {
    submitting.value = false
  }
}

async function deleteComment(commentId) {
  if (!confirm("このコメントを削除しますか？")) return
  await api.del(`/trips/${id}/comments/${commentId}`)
  trip.value.comments = trip.value.comments.filter(c => c.id !== commentId)
  trip.value.comments_count -= 1
}

async function deleteTrip() {
  if (!confirm("この旅行記録を削除しますか？取り消せません。")) return
  await api.del(`/trips/${id}`)
  router.push("/")
}
</script>

<template>
  <div v-if="pending" class="text-center py-12 text-slate-500">読み込み中…</div>
  <div v-else-if="error" class="text-center py-12 text-rose-600">エラー: {{ error.message }}</div>

  <article v-else-if="trip" class="space-y-6">
    <NuxtLink to="/" class="text-sm text-brand-600 hover:underline">← 一覧に戻る</NuxtLink>

    <header class="bg-white p-6 rounded-lg border border-slate-200">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-slate-800">{{ trip.title }}</h1>
          <p class="text-sm text-slate-500 mt-1">{{ trip.started_on }} 〜 {{ trip.ended_on }} / {{ trip.destination }}</p>
          <p class="text-sm text-slate-600 mt-1">@{{ trip.user.display_name }}</p>
          <div class="mt-2 flex flex-wrap gap-1.5 items-center">
            <span class="text-xs px-2 py-0.5 rounded-full bg-brand-100 text-brand-700">{{ labelOf(trip.category) }}</span>
            <NuxtLink
              v-for="name in (trip.tags || [])"
              :key="name"
              :to="`/tags/${encodeURIComponent(name)}`"
              class="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-700 hover:bg-slate-200"
            >#{{ name }}</NuxtLink>
          </div>
        </div>
        <div v-if="isOwner()" class="flex gap-2 shrink-0">
          <NuxtLink :to="`/trips/${trip.id}/edit`" class="text-sm bg-slate-200 px-3 py-1.5 rounded hover:bg-slate-300">編集</NuxtLink>
          <button @click="deleteTrip" class="text-sm bg-rose-500 text-white px-3 py-1.5 rounded hover:bg-rose-600">削除</button>
        </div>
      </div>

      <div v-if="trip.image_urls && trip.image_urls.length" class="grid grid-cols-2 md:grid-cols-3 gap-2 mt-4">
        <img v-for="(url, idx) in trip.image_urls" :key="idx" :src="fullImageUrl(url)" class="w-full aspect-video object-cover rounded" />
      </div>

      <p v-if="trip.body" class="mt-4 text-slate-700 whitespace-pre-wrap">{{ trip.body }}</p>

      <div class="mt-6 flex items-center gap-4">
        <button
          @click="toggleLike"
          :class="[
            'px-3 py-1.5 rounded text-sm flex items-center gap-1 border',
            trip.liked_by_me ? 'bg-rose-50 border-rose-300 text-rose-600' : 'bg-white border-slate-300 text-slate-700 hover:bg-slate-50'
          ]"
        >
          <span>{{ trip.liked_by_me ? "♥" : "♡" }}</span>
          <span>{{ trip.likes_count }} いいね</span>
        </button>
        <span class="text-sm text-slate-500">💬 {{ trip.comments_count }} コメント</span>
      </div>
      <p v-if="actionError" class="mt-2 text-sm text-rose-600">{{ actionError }}</p>
    </header>

    <section v-if="trip.day_entries && trip.day_entries.length" class="bg-white p-6 rounded-lg border border-slate-200">
      <h2 class="font-bold text-slate-800 mb-3">日別の出来事</h2>
      <ol class="space-y-3">
        <li v-for="d in trip.day_entries" :key="d.id" class="border-l-4 border-brand-500 pl-4">
          <p class="text-xs text-slate-500">Day {{ d.day_number }} {{ d.happened_on ? `· ${d.happened_on}` : "" }}</p>
          <h3 class="font-medium text-slate-800">{{ d.title }}</h3>
          <p v-if="d.body" class="text-sm text-slate-600 mt-1 whitespace-pre-wrap">{{ d.body }}</p>
        </li>
      </ol>
    </section>

    <section class="bg-white p-6 rounded-lg border border-slate-200">
      <h2 class="font-bold text-slate-800 mb-3">コメント ({{ trip.comments_count }})</h2>
      <ul class="space-y-3 mb-4">
        <li v-for="c in trip.comments" :key="c.id" class="border-b border-slate-100 pb-3 last:border-0 flex items-start justify-between gap-3">
          <div>
            <p class="text-sm font-medium text-slate-700">@{{ c.user.display_name }}</p>
            <p class="text-sm text-slate-600 mt-0.5 whitespace-pre-wrap">{{ c.body }}</p>
          </div>
          <button v-if="auth.user && c.user.id === auth.user.id" @click="deleteComment(c.id)" class="text-xs text-rose-500 hover:underline shrink-0">削除</button>
        </li>
        <li v-if="!trip.comments.length" class="text-sm text-slate-400">まだコメントはありません。</li>
      </ul>

      <form v-if="auth.user" @submit.prevent="submitComment" class="flex gap-2">
        <input
          v-model="newComment" type="text" maxlength="140" required
          placeholder="コメントを書く (140 文字以内)"
          class="flex-1 border border-slate-300 rounded px-3 py-2 text-sm"
        />
        <button type="submit" :disabled="submitting" class="bg-brand-500 text-white px-4 py-2 rounded text-sm disabled:opacity-50">
          投稿
        </button>
      </form>
      <p v-else class="text-sm text-slate-500">
        コメントするには <NuxtLink :to="`/login?redirect=${route.fullPath}`" class="text-brand-600 underline">ログイン</NuxtLink> してください。
      </p>
    </section>
  </article>
</template>
