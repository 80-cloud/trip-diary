<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"

const auth = useAuthStore()
const router = useRouter()

const email = ref("")
const password = ref("")
const displayName = ref("")
const errors = ref([])
const submitting = ref(false)

async function submit() {
  errors.value = []
  submitting.value = true
  try {
    await auth.signup(email.value, password.value, displayName.value)
    router.push("/")
  } catch (e) {
    errors.value = e.data?.errors || [e.data?.error || "登録に失敗しました"]
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="max-w-md mx-auto bg-white dark:bg-slate-800 p-8 rounded-lg border border-slate-200 dark:border-slate-700 mt-12">
    <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100 mb-6 text-center">サインアップ</h1>

    <form @submit.prevent="submit" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">表示名</label>
        <input v-model="displayName" type="text" required maxlength="30"
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 rounded px-3 py-2" />
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">メールアドレス</label>
        <input v-model="email" type="email" required
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 rounded px-3 py-2" />
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">パスワード (6文字以上)</label>
        <input v-model="password" type="password" required minlength="6"
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 rounded px-3 py-2" />
      </div>
      <ul v-if="errors.length" class="text-sm text-rose-600 list-disc list-inside">
        <li v-for="err in errors" :key="err">{{ err }}</li>
      </ul>
      <button type="submit" :disabled="submitting"
        class="w-full bg-brand-500 text-white py-2 rounded font-medium hover:bg-brand-600 disabled:opacity-50">
        {{ submitting ? "登録中…" : "登録する" }}
      </button>
    </form>

    <p class="text-center text-sm mt-6 text-slate-500 dark:text-slate-400">
      アカウントをお持ちの方は <NuxtLink to="/login" class="text-brand-600 dark:text-brand-50 underline">ログイン</NuxtLink>
    </p>
  </div>
</template>
