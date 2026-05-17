<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const email = ref("taro@example.com")
const password = ref("password")
const error = ref(null)
const submitting = ref(false)

async function submit() {
  error.value = null
  submitting.value = true
  try {
    await auth.login(email.value, password.value)
    const redirect = route.query.redirect || "/"
    router.push(redirect)
  } catch (e) {
    error.value = e.data?.error || "ログインに失敗しました"
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="max-w-md mx-auto bg-white dark:bg-slate-800 p-8 rounded-lg border border-slate-200 dark:border-slate-700 mt-12">
    <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100 mb-6 text-center">ログイン</h1>

    <form @submit.prevent="submit" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">メールアドレス</label>
        <input
          v-model="email" type="email" required
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 rounded px-3 py-2 focus:outline-none focus:ring focus:ring-brand-200 dark:focus:ring-brand-900/60"
        />
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">パスワード</label>
        <input
          v-model="password" type="password" required
          class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 rounded px-3 py-2 focus:outline-none focus:ring focus:ring-brand-200 dark:focus:ring-brand-900/60"
        />
      </div>
      <p v-if="error" class="text-sm text-rose-600">{{ error }}</p>
      <button
        type="submit" :disabled="submitting"
        class="w-full bg-brand-500 text-white py-2 rounded font-medium hover:bg-brand-600 disabled:opacity-50"
      >
        {{ submitting ? "ログイン中…" : "ログイン" }}
      </button>
    </form>

    <p class="text-center text-sm mt-6 text-slate-500 dark:text-slate-400">
      アカウントをお持ちでない方は
      <NuxtLink to="/signup" class="text-brand-600 dark:text-brand-50 underline">サインアップ</NuxtLink>
    </p>
    <div class="mt-6 text-xs text-slate-400 dark:text-slate-500 border-t border-slate-200 dark:border-slate-700 pt-4">
      <p>シードユーザー (開発用):</p>
      <ul class="list-disc list-inside mt-1">
        <li>taro@example.com / password</li>
        <li>hanako@example.com / password</li>
        <li>jiro@example.com / password</li>
      </ul>
    </div>
  </div>
</template>
