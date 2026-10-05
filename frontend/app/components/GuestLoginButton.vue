<script setup>
// 登録せずに試せる一時ゲストでログインするボタン (F-GUEST-01)。
// ログイン画面・ヘッダー・サインアップ停止中の案内の 3 か所で使う。
import { useAuthStore } from "~/composables/useAuthStore.js"

const props = defineProps({
  block: { type: Boolean, default: false }
})

const auth = useAuthStore()
const router = useRouter()
const error = ref(null)
const submitting = ref(false)

// block: ログイン画面などで横幅いっぱいに出す / 既定: ヘッダー用の小さいボタン
const wrapperClass = computed(() => (props.block ? "w-full" : "relative"))
const buttonClass = computed(() => [
  "border border-brand-500 text-brand-600 dark:text-brand-50 rounded font-medium hover:bg-brand-50 dark:hover:bg-slate-700 disabled:opacity-50",
  props.block ? "w-full py-2" : "text-sm px-3 py-1.5 whitespace-nowrap"
])
const errorClass = computed(() => (props.block
  ? "text-sm text-rose-600 mt-2"
  : "absolute right-0 top-full mt-1 w-64 text-xs text-rose-600 bg-white dark:bg-slate-800 border border-rose-200 rounded px-2 py-1 shadow"))

async function handleGuestLogin() {
  if (submitting.value) return
  error.value = null
  submitting.value = true
  try {
    await auth.guestLogin()
    router.push("/")
  } catch (e) {
    error.value = e.data?.error || "ゲストログインに失敗しました"
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div :class="wrapperClass">
    <button type="button" :disabled="submitting" :class="buttonClass" @click="handleGuestLogin">
      <template v-if="submitting">準備中…</template>
      <template v-else-if="block">ゲストとして試す (登録不要)</template>
      <template v-else>
        <span class="sm:hidden">ゲストで試す</span>
        <span class="hidden sm:inline">ゲストとして試す (登録不要)</span>
      </template>
    </button>
    <p v-if="error" role="alert" :class="errorClass">{{ error }}</p>
  </div>
</template>
