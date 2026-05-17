<script setup>
import TripForm from "~/components/TripForm.vue"

definePageMeta({ middleware: "auth" })

const api = useApi()
const router = useRouter()
const route = useRoute()
const errors = ref([])

// ヘッダの「+ 新しい旅行記録」を /trips/new から再クリックされた時の remount 用 key。
// クエリ ?fresh=<timestamp> が変わるたびに TripForm を unmount → mount してフォーム
// 状態をリセットする (Nuxt SPA ルータは同一 path への navigation で再レンダしないため)。
const formKey = computed(() => route.query.fresh || "initial")

async function submit(formData) {
  errors.value = []
  try {
    const trip = await api.post("/trips", { body: formData })
    router.push(`/trips/${trip.id}`)
  } catch (e) {
    errors.value = e.data?.errors || ["登録に失敗しました"]
  }
}
</script>

<template>
  <div>
    <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100 mb-6">新しい旅行記録</h1>
    <TripForm :key="formKey" :errors="errors" @submit="submit" />
  </div>
</template>
