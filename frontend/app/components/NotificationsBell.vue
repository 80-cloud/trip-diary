<script setup>
import { Menu, MenuButton, MenuItems, MenuItem } from "@headlessui/vue"
import { BellIcon } from "@heroicons/vue/24/outline"
import { useNotificationsStore } from "~/composables/useNotificationsStore.js"

const store = useNotificationsStore()
const router = useRouter()

// マウント時は count のみ取得 (転送量最小)
onMounted(() => {
  store.fetchUnreadCount()
})

// ドロップダウンを開いたタイミングで一覧を再取得する。
// Headlessui MenuButton の @click は open/close 両方で発火するため、
// loading 中なら新規 fetch を抑制 (連打/閉じ際の二重 fetch を緩和)。
async function handleOpen() {
  if (store.loading) return
  await store.fetchList()
}

async function handleMarkAllRead() {
  try {
    await store.markAllRead()
  } catch (_e) {
    // 失敗時は次回 fetch で server 側 state に同期する
  }
}

// 通知行クリック: 既読化 + 該当ページ遷移
async function handleClick(notification) {
  if (notification.read_at == null) {
    try {
      await store.markRead(notification.id)
    } catch (_e) {
      // markRead 失敗してもナビゲーションは行う (UX 優先)
    }
  }
  const path = navigationPath(notification)
  if (path) router.push(path)
}

function navigationPath(n) {
  if (n.verb === "followed") return `/users/${n.actor.id}`
  if (n.trip_id) return `/trips/${n.trip_id}`
  return null
}

function verbLabel(verb) {
  return { commented: "がコメントしました", liked: "が「いいね」しました", followed: "があなたをフォローしました" }[verb] || ""
}

function formatTime(iso) {
  if (!iso) return ""
  const d = new Date(iso)
  const diffMs = Date.now() - d.getTime()
  const min = Math.floor(diffMs / 60000)
  if (min < 1)   return "たった今"
  if (min < 60)  return `${min} 分前`
  const hr = Math.floor(min / 60)
  if (hr < 24)   return `${hr} 時間前`
  const day = Math.floor(hr / 24)
  if (day < 7)   return `${day} 日前`
  return d.toLocaleDateString("ja-JP")
}
</script>

<template>
  <Menu as="div" class="relative">
    <MenuButton
      type="button"
      :aria-label="`通知 (${store.unreadCount} 件未読)`"
      class="relative w-10 h-10 flex items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-slate-700"
      @click="handleOpen"
    >
      <BellIcon class="w-6 h-6 text-slate-700 dark:text-slate-200" />
      <span
        v-if="store.unreadCount > 0"
        class="absolute top-1 right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center"
        aria-hidden="true"
      >{{ store.unreadCount > 99 ? "99+" : store.unreadCount }}</span>
    </MenuButton>

    <MenuItems
      class="absolute right-0 mt-2 w-80 max-h-96 overflow-y-auto bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-xl focus:outline-none z-50"
    >
      <div class="flex items-center justify-between px-3 py-2 border-b border-slate-200 dark:border-slate-700">
        <span class="text-sm font-semibold text-slate-700 dark:text-slate-200">通知</span>
        <button
          v-if="store.unreadCount > 0"
          type="button"
          class="text-xs text-brand-600 dark:text-brand-50 hover:underline"
          @click="handleMarkAllRead"
        >すべて既読</button>
      </div>

      <div v-if="store.loading" class="px-3 py-6 text-center text-sm text-slate-500">読み込み中…</div>
      <div v-else-if="store.notifications.length === 0" class="px-3 py-6 text-center text-sm text-slate-500">通知はありません</div>

      <MenuItem
        v-for="n in store.notifications"
        :key="n.id"
        v-slot="{ active }"
      >
        <button
          type="button"
          @click="handleClick(n)"
          :class="[
            'w-full text-left px-3 py-2 border-b border-slate-100 dark:border-slate-700 last:border-0 flex items-start gap-2',
            active ? 'bg-slate-50 dark:bg-slate-700' : '',
            n.read_at == null ? 'bg-blue-50/40 dark:bg-blue-900/20' : ''
          ]"
        >
          <span v-if="n.read_at == null" class="mt-1.5 w-2 h-2 rounded-full bg-blue-500 shrink-0" aria-label="未読" />
          <span v-else class="mt-1.5 w-2 h-2 shrink-0" aria-hidden="true" />
          <span class="flex-1 min-w-0">
            <span class="block text-sm text-slate-800 dark:text-slate-100">
              <span class="font-medium">{{ n.actor.display_name }}</span>
              <span class="text-slate-600 dark:text-slate-300">{{ verbLabel(n.verb) }}</span>
            </span>
            <span class="block text-xs text-slate-500 dark:text-slate-400 mt-0.5">{{ formatTime(n.created_at) }}</span>
          </span>
        </button>
      </MenuItem>
    </MenuItems>
  </Menu>
</template>
