<script setup>
// 存在しない URL などで出るエラーの画面 (Issue #175)。
// 画面を移るとエラーは自動で消えるので、ヘッダーやリンクからそのままほかの画面へ移れる。
const props = defineProps({
  error: { type: Object, required: true }
})

const notFound = computed(() => (props.error.status ?? props.error.statusCode) === 404)

useHead({
  title: computed(() => (notFound.value ? "ページが見つかりません" : "エラーが発生しました") + " — trip-diary"),
  // SPA のため HTTP は 200 を返すので、404 の画面は検索エンジンに登録させない (Issue #194)
  meta: computed(() => (notFound.value ? [{ name: "robots", content: "noindex" }] : []))
})
</script>

<template>
  <NuxtLayout>
    <NotFoundMessage v-if="notFound" />
    <section v-else class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-8 mt-4 text-center">
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">エラーが発生しました</h1>
      <p class="text-sm text-slate-600 dark:text-slate-300 mt-2">時間を置いて、もう一度お試しください。</p>
      <NuxtLink to="/" class="inline-block mt-6 bg-brand-600 text-white px-4 py-2 rounded hover:bg-brand-700">トップへ戻る</NuxtLink>
    </section>
  </NuxtLayout>
</template>
