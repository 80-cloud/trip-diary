<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"
import { useCategories } from "~/composables/useCategories.js"
import { useTripImage } from "~/composables/useTripImage.js"
import ImageCropperModal from "~/components/ImageCropperModal.vue"

const route = useRoute()
const router = useRouter()
const api = useApi()
const auth = useAuthStore()
const config = useRuntimeConfig()
const { labelOf, iconOf, gradientOf } = useCategories()
const { coverImage } = useTripImage()
const id = route.params.id

// Nuxt 4 では useAsyncData の data はデフォルト shallowRef (Nuxt 4 から deep: false が既定)。
// trip.value.liked_by_me = true 等の深いプロパティ代入が UI に反映されないため
// deep: true を明示。like/favorite/コメント/予算/レシート等の mutation を有効化する。
const { data: trip, refresh, pending, error } = await useAsyncData(
  `trip-${id}`,
  () => api.get(`/trips/${id}`),
  { deep: true }
)

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

// F-TICKET-01: チケット CRUD (本人のみ)
const KIND_LABELS = { train: "新幹線/電車", hotel: "宿", flight: "航空券", ticket: "チケット", other: "その他" }
const newTicket = ref({ kind: "train", reservation_no: "", url: "", notes: "" })
const newTicketFile = ref(null)
const ticketError = ref(null)

async function addTicket() {
  ticketError.value = null
  try {
    let body
    if (newTicketFile.value) {
      body = new FormData()
      body.append("kind", newTicket.value.kind)
      body.append("reservation_no", newTicket.value.reservation_no)
      body.append("url", newTicket.value.url)
      body.append("notes", newTicket.value.notes)
      body.append("file", newTicketFile.value)
    } else {
      body = { ...newTicket.value }
    }
    const created = await api.post(`/trips/${id}/tickets`, { body })
    trip.value.tickets.push(created)
    newTicket.value = { kind: "train", reservation_no: "", url: "", notes: "" }
    newTicketFile.value = null
  } catch (e) {
    ticketError.value = e.data?.errors?.join(", ") || "チケット追加に失敗しました"
  }
}

async function deleteTicket(ticket) {
  if (!confirm("このチケットを削除しますか？")) return
  ticketError.value = null
  try {
    await api.del(`/trips/${id}/tickets/${ticket.id}`)
    trip.value.tickets = trip.value.tickets.filter(t => t.id !== ticket.id)
  } catch (e) {
    ticketError.value = e.data?.error || "削除に失敗しました"
  }
}

const ticketCropFile = ref(null)
const ticketInputEl = ref(null)
function onTicketFileChange(e) {
  const f = e.target.files?.[0] || null
  ticketInputEl.value = e.target
  if (!f) { newTicketFile.value = null; return }
  // PDF / 画像以外はクロップせずそのまま使う (チケット PDF は全体保持したい)
  if (f.type && f.type.startsWith("image/")) {
    ticketCropFile.value = f
  } else {
    newTicketFile.value = f
  }
}
function onTicketCropConfirm(file) {
  newTicketFile.value = file
  ticketCropFile.value = null
}
function onTicketCropCancel() {
  ticketCropFile.value = null
  newTicketFile.value = null
  if (ticketInputEl.value) ticketInputEl.value.value = ""
}

function fileUrlFull(path) {
  return path ? fullImageUrl(path) : null
}

// F-REVIEW-01: 旅行レビュー (本人のみ upsert)
const reviewDraft = ref({ rating: 5, body: "" })
const reviewError = ref(null)
const reviewSaving = ref(false)

watch(trip, (t) => {
  if (t?.review) {
    reviewDraft.value = { rating: t.review.rating, body: t.review.body || "" }
  }
}, { immediate: true })

async function saveReview() {
  reviewError.value = null
  reviewSaving.value = true
  try {
    const res = await api.put(`/trips/${id}/review`, { body: { ...reviewDraft.value } })
    trip.value.review = res
  } catch (e) {
    reviewError.value = e.data?.errors?.join(", ") || "レビュー保存に失敗しました"
  } finally {
    reviewSaving.value = false
  }
}

async function deleteReview() {
  if (!confirm("レビューを削除しますか？")) return
  reviewError.value = null
  try {
    await api.del(`/trips/${id}/review`)
    trip.value.review = null
    reviewDraft.value = { rating: 5, body: "" }
  } catch (e) {
    reviewError.value = e.data?.error || "削除に失敗しました"
  }
}

// F-BUDGET-01 / F-RECEIPT-01: 予算とレシート (本人のみ表示・編集)
const RECEIPT_CATEGORIES = [
  { value: "food",        label: "食事" },
  { value: "transport",   label: "交通" },
  { value: "lodging",     label: "宿泊" },
  { value: "sightseeing", label: "観光" },
  { value: "other",       label: "その他" }
]
const CURRENCIES = ["JPY", "USD", "EUR", "GBP", "KRW", "CNY", "TWD"]
const CATEGORY_COLORS = {
  food:        "bg-rose-400",
  transport:   "bg-sky-400",
  lodging:     "bg-amber-400",
  sightseeing: "bg-emerald-400",
  other:       "bg-slate-400"
}

const budgetDraft = ref({ planned_amount: 0, currency: "JPY" })
const budgetError = ref(null)
const budgetSaving = ref(false)
const newReceipt = ref({ amount: "", category: "food", description: "", spent_on: "" })
const receiptError = ref(null)

watch(trip, (t) => {
  if (t?.budget) {
    budgetDraft.value = { planned_amount: Number(t.budget.planned_amount), currency: t.budget.currency }
  }
}, { immediate: true })

function categoryLabel(value) {
  return RECEIPT_CATEGORIES.find(c => c.value === value)?.label || value
}

// 進捗率 (0-100). 予算 0 の場合は 0 を返す (DivideByZero 回避)
function spendingPercent() {
  const planned = Number(trip.value?.budget?.planned_amount || 0)
  const actual  = Number(trip.value?.receipts_total || 0)
  if (planned <= 0) return 0
  return Math.min(100, Math.round((actual / planned) * 100))
}

function categoryPercent(category) {
  const total = Number(trip.value?.receipts_total || 0)
  if (total <= 0) return 0
  const v = Number(trip.value?.receipts_by_category?.[category] || 0)
  return Math.round((v / total) * 100)
}

async function saveBudget() {
  budgetError.value = null
  budgetSaving.value = true
  try {
    const res = await api.put(`/trips/${id}/budget`, { body: { ...budgetDraft.value } })
    trip.value.budget = res
  } catch (e) {
    budgetError.value = e.data?.errors?.join(", ") || "予算保存に失敗しました"
  } finally {
    budgetSaving.value = false
  }
}

async function deleteBudget() {
  if (!confirm("予算を削除しますか？")) return
  budgetError.value = null
  try {
    await api.del(`/trips/${id}/budget`)
    trip.value.budget = null
    budgetDraft.value = { planned_amount: 0, currency: "JPY" }
  } catch (e) {
    budgetError.value = e.data?.error || "削除に失敗しました"
  }
}

async function addReceipt() {
  receiptError.value = null
  try {
    const created = await api.post(`/trips/${id}/receipts`, { body: { ...newReceipt.value } })
    trip.value.receipts.unshift(created)
    // 集計を再計算 (サーバー側で再計算するため API 結果ベースで合計を再算出)
    recalcReceiptTotals()
    newReceipt.value = { amount: "", category: "food", description: "", spent_on: "" }
  } catch (e) {
    receiptError.value = e.data?.errors?.join(", ") || "レシート追加に失敗しました"
  }
}

async function deleteReceipt(receipt) {
  if (!confirm("このレシートを削除しますか？")) return
  receiptError.value = null
  try {
    await api.del(`/trips/${id}/receipts/${receipt.id}`)
    trip.value.receipts = trip.value.receipts.filter(r => r.id !== receipt.id)
    recalcReceiptTotals()
  } catch (e) {
    receiptError.value = e.data?.error || "削除に失敗しました"
  }
}

// クライアント側で receipts_total と receipts_by_category を再算出
// (API を再フェッチせずに集計バーを即時更新するための補助。サーバー値が真実)
function recalcReceiptTotals() {
  const list = trip.value.receipts || []
  let total = 0
  const byCat = RECEIPT_CATEGORIES.reduce((acc, c) => (acc[c.value] = 0, acc), {})
  for (const r of list) {
    const v = Number(r.amount)
    total += v
    if (byCat[r.category] !== undefined) byCat[r.category] += v
    else byCat.other += v
  }
  trip.value.receipts_total = total.toFixed(2)
  trip.value.receipts_by_category = Object.fromEntries(
    Object.entries(byCat).map(([k, v]) => [k, v.toFixed(2)])
  )
}

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
    <NuxtLink to="/" class="text-sm text-brand-600 dark:text-brand-50 hover:underline">← 一覧に戻る</NuxtLink>

    <header class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 overflow-hidden relative">
      <!-- カテゴリリボン (左上斜め) -->
      <div :class="['absolute top-3 -left-8 z-10 px-9 py-1 -rotate-45 text-[10px] tracking-widest font-bold text-white shadow-lg ring-1 ring-white/40 bg-gradient-to-r', gradientOf(trip.category)]">
        {{ labelOf(trip.category) }}
      </div>

      <!-- カバー画像 (フルブリード・タイトルオーバーレイ) -->
      <div :class="['relative aspect-[21/9] md:aspect-[3/1] bg-gradient-to-br', gradientOf(trip.category)]">
        <img :src="coverImage(trip, 1200, 500)" :alt="trip.title" class="absolute inset-0 w-full h-full object-cover" loading="eager" >
        <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/30 to-transparent"/>
        <span v-if="trip.status === 'draft'" class="absolute top-3 right-3 text-xs px-2 py-0.5 rounded bg-amber-100 dark:bg-amber-900 text-amber-700 dark:text-amber-200 font-bold shadow">下書き</span>
        <div class="absolute bottom-0 left-0 right-0 p-5 md:p-6 text-white">
          <div class="flex items-center gap-2 text-sm opacity-90 mb-1">
            <span>{{ iconOf(trip.category) }}</span><span>{{ labelOf(trip.category) }}</span>
            <span>·</span><span>📍 {{ trip.destination }}</span>
          </div>
          <h1 class="text-2xl md:text-3xl font-bold leading-tight drop-shadow">{{ trip.title }}</h1>
          <p class="mt-1 text-sm opacity-90">{{ trip.started_on }} 〜 {{ trip.ended_on }}</p>
        </div>
      </div>

      <!-- メタ情報 (著者 + タグ + 編集/削除) -->
      <div class="p-6">
        <div class="flex items-start justify-between gap-4">
          <div class="flex-1 min-w-0">
            <p class="text-sm text-slate-600 dark:text-slate-300 flex items-center gap-2">
              <NuxtLink :to="`/users/${trip.user.id}`" class="hover:underline font-medium">@{{ trip.user.display_name }}</NuxtLink>
              <button
                v-if="auth.user && auth.user.id !== trip.user.id"
                :class="[
                  'text-[10px] px-2 py-0.5 rounded border',
                  trip.user.followed_by_me
                    ? 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-slate-300 dark:border-slate-600'
                    : 'bg-brand-500 text-white border-brand-500'
                ]"
                @click="toggleFollow"
              >{{ trip.user.followed_by_me ? "フォロー中" : "+ フォロー" }}</button>
            </p>
            <div v-if="(trip.tags || []).length" class="mt-2 flex flex-wrap gap-1.5 items-center">
              <NuxtLink
                v-for="name in (trip.tags || [])"
                :key="name"
                :to="`/tags/${encodeURIComponent(name)}`"
                class="text-xs px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-600"
              >#{{ name }}</NuxtLink>
            </div>
          </div>
          <div v-if="isOwner()" class="flex gap-2 shrink-0">
            <NuxtLink :to="`/trips/${trip.id}/edit`" class="text-sm bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-100 px-3 py-1.5 rounded hover:bg-slate-300 dark:hover:bg-slate-600">編集</NuxtLink>
            <button type="button" class="text-sm bg-rose-500 text-white px-3 py-1.5 rounded hover:bg-rose-600" @click="deleteTrip">削除</button>
          </div>
        </div>

        <!-- ユーザーがアップした追加画像 (2 枚目以降) -->
        <div v-if="trip.image_urls && trip.image_urls.length > 1" class="grid grid-cols-2 md:grid-cols-3 gap-2 mt-4">
          <img v-for="(url, idx) in trip.image_urls.slice(1)" :key="idx" :src="fullImageUrl(url)" class="w-full aspect-video object-cover rounded" >
        </div>

        <p v-if="trip.body" class="mt-4 text-slate-700 dark:text-slate-200 whitespace-pre-wrap">{{ trip.body }}</p>

        <div class="mt-6 flex flex-wrap items-center gap-2">
        <button
          :class="[
            'px-3 py-1.5 rounded text-sm flex items-center gap-1 border',
            trip.liked_by_me ? 'bg-rose-50 border-rose-300 text-rose-600 dark:bg-rose-950 dark:border-rose-700 dark:text-rose-200' : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700'
          ]"
          @click="toggleLike"
        >
          <span>{{ trip.liked_by_me ? "♥" : "♡" }}</span>
          <span>{{ trip.likes_count }} いいね</span>
        </button>
        <button
          :class="[
            'px-3 py-1.5 rounded text-sm flex items-center gap-1 border',
            trip.favorited_by_me ? 'bg-amber-50 border-amber-300 text-amber-700 dark:bg-amber-950 dark:border-amber-700 dark:text-amber-200' : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700'
          ]"
          @click="toggleFavorite"
        >
          <span>{{ trip.favorited_by_me ? "★" : "☆" }}</span>
          <span>{{ trip.favorited_by_me ? "お気に入り済" : "お気に入り" }}</span>
        </button>
        <span class="text-sm text-slate-500 dark:text-slate-400">💬 {{ trip.comments_count }} コメント</span>
        </div>
        <p v-if="actionError" class="mt-2 text-sm text-rose-600">{{ actionError }}</p>
      </div>
    </header>

    <!-- F-PLAN-03: 進捗バー (本人のみ / F-LEAK-01 fix: count は本人にしか返らない) -->
    <section v-if="isOwner() && trip.planned_count > 0" class="bg-white dark:bg-slate-800 p-4 rounded-lg border border-slate-200 dark:border-slate-700">
      <div class="flex items-center justify-between mb-2">
        <h2 class="text-sm font-bold text-slate-700 dark:text-slate-200">計画達成度</h2>
        <span class="text-xs text-slate-500 dark:text-slate-400">{{ trip.planned_done_count }} / {{ trip.planned_count }} 件 ({{ planProgress }}%)</span>
      </div>
      <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded overflow-hidden">
        <div class="h-full bg-brand-500 transition-all" :style="{ width: `${planProgress}%` }"/>
      </div>
    </section>

    <!-- F-PLAN-01/02: 計画スポット (本人のみ表示・編集) -->
    <section v-if="isOwner()" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">計画スポット <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span></h2>
      <ul class="space-y-2 mb-3">
        <li v-for="spot in trip.planned_spots" :key="spot.id" class="flex items-center gap-2">
          <input type="checkbox" :checked="spot.done" class="rounded" @change="toggleSpotDone(spot)" >
          <span :class="['flex-1 text-sm', spot.done ? 'line-through text-slate-400 dark:text-slate-500' : 'text-slate-700 dark:text-slate-200']">{{ spot.title }}</span>
          <span v-if="spot.day_entry_id" class="text-[10px] px-1.5 py-0.5 rounded bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50">記録に追加済</span>
          <button type="button" class="text-xs text-rose-500 hover:underline" @click="deleteSpot(spot)">削除</button>
        </li>
        <li v-if="trip.planned_spots.length === 0" class="text-xs text-slate-400 dark:text-slate-500">まだ計画はありません</li>
      </ul>
      <form class="flex gap-2" @submit.prevent="addSpot">
        <input
v-model="newSpotTitle" maxlength="80" placeholder="新しい計画 (例: 金閣寺)"
          class="flex-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-1.5 text-sm" >
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
          <input type="checkbox" :checked="item.packed" class="rounded" @change="toggleItemPacked(item)" >
          <span :class="['flex-1 text-sm', item.packed ? 'line-through text-slate-400 dark:text-slate-500' : 'text-slate-700 dark:text-slate-200']">{{ item.body }}</span>
          <button type="button" class="text-xs text-rose-500 hover:underline" @click="deleteItem(item)">削除</button>
        </li>
        <li v-if="trip.packing_items.length === 0" class="text-xs text-slate-400 dark:text-slate-500">まだ持ち物はありません</li>
      </ul>
      <form class="flex gap-2" @submit.prevent="addItem">
        <input
v-model="newItemBody" maxlength="80" placeholder="新しい持ち物 (例: 歯ブラシ)"
          class="flex-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-1.5 text-sm" >
        <button type="submit" class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600">追加</button>
      </form>
      <p v-if="packError" class="text-xs text-rose-600 mt-2">{{ packError }}</p>
    </section>

    <!-- F-TICKET-01: チケット (本人のみ表示・編集) -->
    <section v-if="isOwner()" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">チケット <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span></h2>
      <ul class="space-y-2 mb-3">
        <li v-for="t in trip.tickets" :key="t.id" class="flex items-start gap-2 border-b border-slate-100 dark:border-slate-700 pb-2 last:border-0">
          <span class="text-[10px] px-1.5 py-0.5 rounded bg-brand-100 dark:bg-brand-700 text-brand-700 dark:text-brand-50 shrink-0">{{ KIND_LABELS[t.kind] || t.kind }}</span>
          <div class="flex-1 text-sm text-slate-700 dark:text-slate-200">
            <p v-if="t.reservation_no" class="font-medium">予約番号: {{ t.reservation_no }}</p>
            <a v-if="t.url" :href="t.url" target="_blank" rel="noopener" class="text-brand-600 dark:text-brand-50 hover:underline text-xs break-all">{{ t.url }}</a>
            <p v-if="t.notes" class="text-xs text-slate-500 dark:text-slate-400">{{ t.notes }}</p>
            <a v-if="t.file_url" :href="fileUrlFull(t.file_url)" target="_blank" rel="noopener" class="text-xs text-slate-500 dark:text-slate-400 underline">添付ファイル</a>
          </div>
          <button type="button" class="text-xs text-rose-500 hover:underline shrink-0" @click="deleteTicket(t)">削除</button>
        </li>
        <li v-if="trip.tickets.length === 0" class="text-xs text-slate-400 dark:text-slate-500">まだチケットはありません</li>
      </ul>
      <form class="space-y-2" @submit.prevent="addTicket">
        <div class="flex gap-2">
          <select v-model="newTicket.kind" class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm">
            <option v-for="(label, key) in KIND_LABELS" :key="key" :value="key">{{ label }}</option>
          </select>
          <input
v-model="newTicket.reservation_no" maxlength="80" placeholder="予約番号"
            class="flex-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm" >
        </div>
        <input
v-model="newTicket.url" maxlength="500" placeholder="URL (任意)"
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm" >
        <input
v-model="newTicket.notes" maxlength="500" placeholder="メモ (任意)"
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm" >
        <input
id="ticket-file-input" type="file" accept="image/*,application/pdf" class="absolute w-0 h-0 opacity-0 pointer-events-none -z-10"
          @change="onTicketFileChange" >
        <div class="flex items-center gap-3 flex-wrap">
          <label
            for="ticket-file-input"
            class="inline-block cursor-pointer bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 px-4 py-1.5 rounded text-sm font-medium hover:bg-slate-300 dark:hover:bg-slate-600"
          >ファイルを選択 (画像 / PDF)</label>
          <span v-if="newTicketFile" class="text-xs text-slate-600 dark:text-slate-300 truncate">{{ newTicketFile.name }}</span>
        </div>
        <button type="submit" class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600">追加</button>
        <p v-if="ticketError" class="text-xs text-rose-600">{{ ticketError }}</p>
      </form>
    </section>

    <!-- F-REVIEW-01: 旅行レビュー (全員に公開・本人のみ編集) -->
    <section class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">
        旅行の振り返り
        <span v-if="isOwner()" class="text-xs font-normal text-slate-500 dark:text-slate-400">(他のユーザーにも公開されます)</span>
      </h2>
      <!-- 表示 (誰でも見える): review があれば表示 -->
      <div v-if="trip.review && !isOwner()" class="text-sm">
        <p class="text-amber-500 text-lg">{{ "★".repeat(trip.review.rating) }}<span class="text-slate-300 dark:text-slate-600">{{ "★".repeat(5 - trip.review.rating) }}</span></p>
        <p v-if="trip.review.body" class="text-slate-700 dark:text-slate-200 mt-2 whitespace-pre-wrap">{{ trip.review.body }}</p>
      </div>
      <p v-else-if="!trip.review && !isOwner()" class="text-xs text-slate-400 dark:text-slate-500">まだレビューはありません</p>

      <!-- 編集 (本人のみ) -->
      <form v-if="isOwner()" class="space-y-2" @submit.prevent="saveReview">
        <label class="block text-xs text-slate-600 dark:text-slate-400">5 段階評価</label>
        <select v-model.number="reviewDraft.rating" class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm">
          <option v-for="r in [1, 2, 3, 4, 5]" :key="r" :value="r">{{ r }} {{ "★".repeat(r) }}</option>
        </select>
        <textarea
v-model="reviewDraft.body" rows="3" maxlength="2000" placeholder="振り返り (2000 字以内 / 任意)"
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-2 text-sm"/>
        <div class="flex items-center gap-2">
          <button type="submit" :disabled="reviewSaving" class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600 disabled:opacity-50">{{ reviewSaving ? "保存中…" : (trip.review ? "更新" : "保存") }}</button>
          <button v-if="trip.review" type="button" class="text-xs text-rose-500 hover:underline" @click="deleteReview">レビューを削除</button>
        </div>
        <p v-if="reviewError" class="text-xs text-rose-600">{{ reviewError }}</p>
      </form>
    </section>

    <!-- F-BUDGET-01 / F-RECEIPT-01: 予算とレシート (本人のみ) -->
    <section v-if="isOwner()" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">
        予算とレシート
        <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span>
      </h2>

      <!-- 予算 upsert form -->
      <form class="space-y-2 mb-4" @submit.prevent="saveBudget">
        <div class="flex flex-wrap items-end gap-2">
          <label class="block text-xs text-slate-600 dark:text-slate-400">
            予算
            <input
              v-model.number="budgetDraft.planned_amount" type="number" min="0" step="1"
              class="block w-32 mt-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm"
            >
          </label>
          <label class="block text-xs text-slate-600 dark:text-slate-400">
            通貨
            <select v-model="budgetDraft.currency" class="block mt-1 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm">
              <option v-for="c in CURRENCIES" :key="c" :value="c">{{ c }}</option>
            </select>
          </label>
          <button
type="submit" :disabled="budgetSaving"
            class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600 disabled:opacity-50">
            {{ budgetSaving ? "保存中…" : (trip.budget ? "予算を更新" : "予算を保存") }}
          </button>
          <button v-if="trip.budget" type="button" class="text-xs text-rose-500 hover:underline" @click="deleteBudget">予算を削除</button>
        </div>
        <p v-if="budgetError" class="text-xs text-rose-600">{{ budgetError }}</p>
      </form>

      <!-- 進捗バー: planned vs actual -->
      <div v-if="trip.budget && Number(trip.budget.planned_amount) > 0" class="mb-4">
        <div class="flex justify-between text-xs text-slate-600 dark:text-slate-400 mb-1">
          <span>支出 {{ trip.receipts_total }} / 予算 {{ trip.budget.planned_amount }} {{ trip.budget.currency }}</span>
          <span :class="spendingPercent() >= 100 ? 'text-rose-500 font-bold' : ''">{{ spendingPercent() }}%</span>
        </div>
        <div class="w-full h-3 bg-slate-200 dark:bg-slate-700 rounded overflow-hidden">
          <div
:class="['h-full', spendingPercent() >= 100 ? 'bg-rose-500' : 'bg-emerald-500']"
            :style="{ width: spendingPercent() + '%' }"/>
        </div>
      </div>

      <!-- カテゴリ別バー -->
      <div v-if="Number(trip.receipts_total || 0) > 0" class="mb-4 space-y-1">
        <p class="text-xs text-slate-600 dark:text-slate-400">カテゴリ別内訳</p>
        <div v-for="c in RECEIPT_CATEGORIES" :key="c.value" class="flex items-center gap-2 text-xs">
          <span class="w-12 text-slate-600 dark:text-slate-300">{{ c.label }}</span>
          <div class="flex-1 h-2 bg-slate-200 dark:bg-slate-700 rounded overflow-hidden">
            <div :class="['h-full', CATEGORY_COLORS[c.value]]" :style="{ width: categoryPercent(c.value) + '%' }"/>
          </div>
          <span class="w-24 text-right tabular-nums text-slate-700 dark:text-slate-200">{{ trip.receipts_by_category?.[c.value] || "0.00" }}</span>
        </div>
      </div>

      <!-- レシート追加 form -->
      <form class="space-y-2 border-t border-slate-200 dark:border-slate-700 pt-3" @submit.prevent="addReceipt">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
          <input
v-model.number="newReceipt.amount" type="number" min="1" step="1" required placeholder="金額"
            class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm" >
          <select
v-model="newReceipt.category"
            class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm">
            <option v-for="c in RECEIPT_CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
          </select>
          <input
v-model="newReceipt.spent_on" type="date"
            class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm" >
          <input
v-model="newReceipt.description" type="text" maxlength="200" placeholder="メモ (任意)"
            class="border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-2 py-1 text-sm" >
        </div>
        <button
type="submit"
          class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600">レシートを追加</button>
        <p v-if="receiptError" class="text-xs text-rose-600">{{ receiptError }}</p>
      </form>

      <!-- レシート一覧 -->
      <ul class="mt-3 space-y-1">
        <li
v-for="r in trip.receipts" :key="r.id"
          class="flex items-center justify-between text-sm border-b border-slate-100 dark:border-slate-700 pb-1 last:border-0">
          <div class="flex items-center gap-2 min-w-0">
            <span :class="['inline-block w-2 h-2 rounded-full shrink-0', CATEGORY_COLORS[r.category]]"/>
            <span class="text-xs text-slate-500 dark:text-slate-400 w-12">{{ categoryLabel(r.category) }}</span>
            <span class="tabular-nums text-slate-800 dark:text-slate-100">{{ r.amount }}</span>
            <span v-if="r.spent_on" class="text-xs text-slate-500 dark:text-slate-400">{{ r.spent_on }}</span>
            <span v-if="r.description" class="text-xs text-slate-600 dark:text-slate-300 truncate">{{ r.description }}</span>
          </div>
          <button type="button" class="text-xs text-rose-500 hover:underline shrink-0" @click="deleteReceipt(r)">削除</button>
        </li>
        <li v-if="!trip.receipts.length" class="text-xs text-slate-400 dark:text-slate-500">まだレシートはありません</li>
      </ul>
    </section>

    <!-- F-MEMO-01: 個人メモ (本人のみ表示・本人のみ参照可) -->
    <section v-if="auth.user" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-2">個人メモ <span class="text-xs font-normal text-slate-500 dark:text-slate-400">(自分にだけ見えます)</span></h2>
      <textarea
        v-model="memoDraft" rows="3" maxlength="2000"
        placeholder="この旅行について自分用のメモ (2000 字以内)"
        class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 dark:text-slate-100 rounded px-3 py-2 text-sm"
      />
      <div class="mt-2 flex items-center justify-between">
        <span v-if="memoMsg" class="text-xs text-slate-500 dark:text-slate-400">{{ memoMsg }}</span>
        <button
          :disabled="memoSaving" class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm disabled:opacity-50 hover:bg-brand-600 ml-auto"
          @click="saveMemo"
        >{{ memoSaving ? "保存中…" : (memoDraft ? "メモを保存" : "メモを削除") }}</button>
      </div>
    </section>

    <section v-if="trip.day_entries && trip.day_entries.length" class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">日別の出来事</h2>
      <ol class="space-y-3">
        <li v-for="d in trip.day_entries" :key="d.id" class="border-l-4 border-brand-500 pl-4">
          <p class="text-xs text-slate-500 dark:text-slate-400">Day {{ d.day_number }} {{ d.happened_on ? `· ${d.happened_on}` : "" }}</p>
          <h3 class="font-medium text-slate-800 dark:text-slate-100">{{ d.title }}</h3>
          <p v-if="d.body" class="text-sm text-slate-600 dark:text-slate-300 mt-1 whitespace-pre-wrap">{{ d.body }}</p>
        </li>
      </ol>
    </section>

    <section class="bg-white dark:bg-slate-800 p-6 rounded-lg border border-slate-200 dark:border-slate-700">
      <h2 class="font-bold text-slate-800 dark:text-slate-100 mb-3">コメント ({{ trip.comments_count }})</h2>
      <ul class="space-y-3 mb-4">
        <li v-for="c in trip.comments" :key="c.id" class="border-b border-slate-100 dark:border-slate-700 pb-3 last:border-0 flex items-start justify-between gap-3">
          <div>
            <p class="text-sm font-medium text-slate-700 dark:text-slate-200">@{{ c.user.display_name }}</p>
            <p class="text-sm text-slate-600 dark:text-slate-300 mt-0.5 whitespace-pre-wrap">{{ c.body }}</p>
          </div>
          <button v-if="auth.user && c.user.id === auth.user.id" type="button" class="text-xs text-rose-500 hover:underline shrink-0" @click="deleteComment(c.id)">削除</button>
        </li>
        <li v-if="!trip.comments.length" class="text-sm text-slate-400">まだコメントはありません。</li>
      </ul>

      <form v-if="auth.user" class="flex gap-2" @submit.prevent="submitComment">
        <input
          v-model="newComment" type="text" maxlength="140" required
          placeholder="コメントを書く (140 文字以内)"
          class="flex-1 border border-slate-300 rounded px-3 py-2 text-sm"
        >
        <button type="submit" :disabled="submitting" class="bg-brand-500 text-white px-4 py-2 rounded text-sm disabled:opacity-50">
          投稿
        </button>
      </form>
      <p v-else class="text-sm text-slate-500">
        コメントするには <NuxtLink :to="`/login?redirect=${route.fullPath}`" class="text-brand-600 dark:text-brand-50 underline">ログイン</NuxtLink> してください。
      </p>
    </section>
  </article>
  <ImageCropperModal
    v-if="ticketCropFile"
    :file="ticketCropFile"
    :filename="ticketCropFile?.name || 'ticket.jpg'"
    @confirm="onTicketCropConfirm"
    @cancel="onTicketCropCancel"
  />
</template>
