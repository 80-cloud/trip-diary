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
const memoDraft = ref("")
const memoSaving = ref(false)
const memoMsg = ref(null)

// trip ロード後にメモ入力欄を同期 (server truth → form state)
watch(trip, (t) => {
  if (t) memoDraft.value = t.my_memo || ""
}, { immediate: true })

function isOwner() {
  return auth.user && trip.value && trip.value.user.id === auth.user.id
}

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}

async function toggleFavorite() {
  if (!auth.user) {
    router.push({ path: "/login", query: { redirect: route.fullPath } })
    return
  }
  actionError.value = null
  try {
    if (trip.value.favorited_by_me) {
      await api.del(`/trips/${id}/favorite`)
      trip.value.favorited_by_me = false
    } else {
      await api.post(`/trips/${id}/favorite`)
      trip.value.favorited_by_me = true
    }
  } catch (e) {
    actionError.value = e.data?.error || "お気に入り操作に失敗しました"
  }
}

async function saveMemo() {
  if (!auth.user) return
  memoSaving.value = true
  memoMsg.value = null
  try {
    const res = await api.put(`/trips/${id}/memo`, { body: { body: memoDraft.value } })
    trip.value.my_memo = res.memo
    memoMsg.value = res.memo ? "メモを保存しました" : "メモを削除しました"
  } catch (e) {
    memoMsg.value = e.data?.errors?.join(", ") || "メモ保存に失敗しました"
  } finally {
    memoSaving.value = false
  }
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

// F-PLAN: 計画スポット CRUD (本人のみ)
const newSpotTitle = ref("")
const planError = ref(null)
async function addSpot() {
  const title = newSpotTitle.value.trim()
  if (!title) return
  planError.value = null
  try {
    const created = await api.post(`/trips/${id}/planned_spots`, { body: { title } })
    trip.value.planned_spots.push(created)
    trip.value.planned_count += 1
    newSpotTitle.value = ""
  } catch (e) {
    planError.value = e.data?.errors?.join(", ") || "計画追加に失敗しました"
  }
}
async function toggleSpotDone(spot) {
  const next = !spot.done
  const wasNotPromoted = !spot.day_entry_id
  planError.value = null
  try {
    const updated = await api.patch(`/trips/${id}/planned_spots/${spot.id}`, { body: { done: next } })
    spot.done = updated.done
    spot.day_entry_id = updated.day_entry_id
    trip.value.planned_done_count += next ? 1 : -1
    // F-PLAN-02: done=false→true で新規 DayEntry が作成された場合、
    // UI の day_entries 一覧にも反映するため trip 全体を refetch (簡易)
    if (next && wasNotPromoted && updated.day_entry_id) {
      await refresh()
    }
  } catch (e) {
    planError.value = e.data?.errors?.join(", ") || "更新に失敗しました"
  }
}
async function deleteSpot(spot) {
  if (!confirm(`「${spot.title}」を計画から削除しますか？`)) return
  planError.value = null
  try {
    await api.del(`/trips/${id}/planned_spots/${spot.id}`)
    trip.value.planned_spots = trip.value.planned_spots.filter(s => s.id !== spot.id)
    trip.value.planned_count -= 1
    if (spot.done) trip.value.planned_done_count -= 1
  } catch (e) {
    planError.value = e.data?.error || "削除に失敗しました"
  }
}

// F-PACK: 持ち物 CRUD (本人のみ)
const newItemBody = ref("")
const packError = ref(null)
async function addItem() {
  const body = newItemBody.value.trim()
  if (!body) return
  packError.value = null
  try {
    const created = await api.post(`/trips/${id}/packing_items`, { body: { body } })
    trip.value.packing_items.push(created)
    newItemBody.value = ""
  } catch (e) {
    packError.value = e.data?.errors?.join(", ") || "持ち物追加に失敗しました"
  }
}
async function toggleItemPacked(item) {
  packError.value = null
  try {
    const updated = await api.patch(`/trips/${id}/packing_items/${item.id}`, { body: { packed: !item.packed } })
    item.packed = updated.packed
  } catch (e) {
    packError.value = e.data?.error || "更新に失敗しました"
  }
}
async function deleteItem(item) {
  packError.value = null
  try {
    await api.del(`/trips/${id}/packing_items/${item.id}`)
    trip.value.packing_items = trip.value.packing_items.filter(i => i.id !== item.id)
  } catch (e) {
    packError.value = e.data?.error || "削除に失敗しました"
  }
}

const planProgress = computed(() => {
  if (!trip.value || !trip.value.planned_count) return 0
  return Math.round((trip.value.planned_done_count / trip.value.planned_count) * 100)
})

// F-FOLLOW-01: 投稿者を follow/unfollow
async function toggleFollow() {
  if (!auth.user) {
    router.push({ path: "/login", query: { redirect: route.fullPath } })
    return
  }
  const targetId = trip.value.user.id
  try {
    if (trip.value.user.followed_by_me) {
      await api.del(`/users/${targetId}/follow`)
      trip.value.user.followed_by_me = false
    } else {
      await api.post(`/users/${targetId}/follow`)
      trip.value.user.followed_by_me = true
    }
  } catch (e) {
    actionError.value = e.data?.errors?.join(", ") || "フォロー操作に失敗しました"
  }
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
          <div class="flex items-center gap-2 flex-wrap">
            <span v-if="trip.status === 'draft'" class="text-xs px-2 py-0.5 rounded bg-amber-100 dark:bg-amber-900 text-amber-700 dark:text-amber-200 font-bold">下書き</span>
            <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ trip.title }}</h1>
          </div>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">{{ trip.started_on }} 〜 {{ trip.ended_on }} / {{ trip.destination }}</p>
          <p class="text-sm text-slate-600 dark:text-slate-300 mt-1 flex items-center gap-2">
            <NuxtLink :to="`/users/${trip.user.id}`" class="hover:underline">@{{ trip.user.display_name }}</NuxtLink>
            <button
              v-if="auth.user && auth.user.id !== trip.user.id"
              @click="toggleFollow"
              :class="[
                'text-[10px] px-2 py-0.5 rounded border',
                trip.user.followed_by_me
                  ? 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-slate-300 dark:border-slate-600'
                  : 'bg-brand-500 text-white border-brand-500'
              ]"
            >{{ trip.user.followed_by_me ? "フォロー中" : "+ フォロー" }}</button>
          </p>
          <div class="mt-2 flex flex-wrap gap-1.5 items-center">
            <span class="text-xs px-2 py-0.5 rounded-full bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50">{{ labelOf(trip.category) }}</span>
            <NuxtLink
              v-for="name in (trip.tags || [])"
              :key="name"
              :to="`/tags/${encodeURIComponent(name)}`"
              class="text-xs px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-600"
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

      <div class="mt-6 flex flex-wrap items-center gap-2">
        <button
          @click="toggleLike"
          :class="[
            'px-3 py-1.5 rounded text-sm flex items-center gap-1 border',
            trip.liked_by_me ? 'bg-rose-50 border-rose-300 text-rose-600 dark:bg-rose-950 dark:border-rose-700 dark:text-rose-200' : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700'
          ]"
        >
          <span>{{ trip.liked_by_me ? "♥" : "♡" }}</span>
          <span>{{ trip.likes_count }} いいね</span>
        </button>
        <button
          @click="toggleFavorite"
          :class="[
            'px-3 py-1.5 rounded text-sm flex items-center gap-1 border',
            trip.favorited_by_me ? 'bg-amber-50 border-amber-300 text-amber-700 dark:bg-amber-950 dark:border-amber-700 dark:text-amber-200' : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700'
          ]"
        >
          <span>{{ trip.favorited_by_me ? "★" : "☆" }}</span>
          <span>{{ trip.favorited_by_me ? "お気に入り済" : "お気に入り" }}</span>
        </button>
        <span class="text-sm text-slate-500 dark:text-slate-400">💬 {{ trip.comments_count }} コメント</span>
      </div>
      <p v-if="actionError" class="mt-2 text-sm text-rose-600">{{ actionError }}</p>
    </header>

    <!-- F-PLAN-03: 進捗バー (誰でも見える / 件数のみ) -->
    <section v-if="trip.planned_count > 0" class="bg-white dark:bg-slate-800 p-4 rounded-lg border border-slate-200 dark:border-slate-700">
      <div class="flex items-center justify-between mb-2">
        <h2 class="text-sm font-bold text-slate-700 dark:text-slate-200">計画達成度</h2>
        <span class="text-xs text-slate-500 dark:text-slate-400">{{ trip.planned_done_count }} / {{ trip.planned_count }} 件 ({{ planProgress }}%)</span>
      </div>
      <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded overflow-hidden">
        <div class="h-full bg-brand-500 transition-all" :style="{ width: `${planProgress}%` }"></div>
      </div>
    </section>

    <!-- F-PLAN-01/02: 計画スポット (本人のみ表示・編集) -->
    <section v-if="isOwner()" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">計画スポット <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span></h2>
      <ul class="space-y-2 mb-3">
        <li v-for="spot in trip.planned_spots" :key="spot.id" class="flex items-center gap-2">
          <input type="checkbox" :checked="spot.done" @change="toggleSpotDone(spot)" class="rounded" />
          <span :class="['flex-1 text-sm', spot.done ? 'line-through text-slate-400 dark:text-slate-500' : 'text-slate-700 dark:text-slate-200']">{{ spot.title }}</span>
          <span v-if="spot.day_entry_id" class="text-[10px] px-1.5 py-0.5 rounded bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50">記録に追加済</span>
          <button @click="deleteSpot(spot)" class="text-xs text-rose-500 hover:underline">削除</button>
        </li>
        <li v-if="trip.planned_spots.length === 0" class="text-xs text-slate-400 dark:text-slate-500">まだ計画はありません</li>
      </ul>
      <form @submit.prevent="addSpot" class="flex gap-2">
        <input v-model="newSpotTitle" maxlength="80" placeholder="新しい計画 (例: 金閣寺)"
          class="flex-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-1.5 text-sm" />
        <button type="submit" class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600">追加</button>
      </form>
      <p v-if="planError" class="text-xs text-rose-600 mt-2">{{ planError }}</p>
      <p class="text-xs text-slate-400 dark:text-slate-500 mt-2">✓ にすると自動で「日別の出来事」に追加されます</p>
    </section>

    <!-- F-PACK-01: 持ち物チェックリスト (本人のみ表示・編集) -->
    <section v-if="isOwner()" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">持ち物チェックリスト <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span></h2>
      <ul class="space-y-2 mb-3">
        <li v-for="item in trip.packing_items" :key="item.id" class="flex items-center gap-2">
          <input type="checkbox" :checked="item.packed" @change="toggleItemPacked(item)" class="rounded" />
          <span :class="['flex-1 text-sm', item.packed ? 'line-through text-slate-400 dark:text-slate-500' : 'text-slate-700 dark:text-slate-200']">{{ item.body }}</span>
          <button @click="deleteItem(item)" class="text-xs text-rose-500 hover:underline">削除</button>
        </li>
        <li v-if="trip.packing_items.length === 0" class="text-xs text-slate-400 dark:text-slate-500">まだ持ち物はありません</li>
      </ul>
      <form @submit.prevent="addItem" class="flex gap-2">
        <input v-model="newItemBody" maxlength="80" placeholder="新しい持ち物 (例: 歯ブラシ)"
          class="flex-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-1.5 text-sm" />
        <button type="submit" class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600">追加</button>
      </form>
      <p v-if="packError" class="text-xs text-rose-600 mt-2">{{ packError }}</p>
    </section>

    <!-- F-MEMO-01: 個人メモ (本人のみ表示・本人のみ参照可) -->
    <section v-if="auth.user" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-2">個人メモ <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span></h2>
      <textarea
        v-model="memoDraft" rows="3" maxlength="2000"
        placeholder="この旅行について自分用のメモ (2000 字以内)"
        class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-2 text-sm"
      ></textarea>
      <div class="mt-2 flex items-center justify-between">
        <span v-if="memoMsg" class="text-xs text-slate-500 dark:text-slate-400">{{ memoMsg }}</span>
        <button
          @click="saveMemo" :disabled="memoSaving"
          class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm disabled:opacity-50 hover:bg-brand-600 ml-auto"
        >{{ memoSaving ? "保存中…" : (memoDraft ? "メモを保存" : "メモを削除") }}</button>
      </div>
    </section>

    <section v-if="trip.day_entries && trip.day_entries.length" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
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
