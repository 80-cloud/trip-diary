<script setup>
import TripForm from "~/components/TripForm.vue"

definePageMeta({ middleware: "auth" })

const route = useRoute()
const router = useRouter()
const api = useApi()
const id = route.params.id

// Nuxt 4 useAsyncData は default shallow。編集フォームは TripForm に initial で渡すだけだが、
// 一貫性のため deep:true を指定。
const { data: trip } = await useAsyncData(
  `trip-edit-${id}`,
  () => api.get(`/trips/${id}`),
  { deep: true }
)
const errors = ref([])

async function submit(formData) {
  errors.value = []
  try {
    await api.patch(`/trips/${id}`, { body: formData })
    router.push(`/trips/${id}`)
  } catch (e) {
    errors.value = e.data?.errors || ["更新に失敗しました"]
  }
}
</script>

<template>
  <div>
    <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100 mb-6">旅行記録を編集</h1>
    <!-- :key にロード後の trip.id を渡し、データ到着前のからっぽマウントを防ぐ -->
    <TripForm v-if="trip" :key="trip.id" :initial="trip" @submit="submit" :errors="errors" />
  </div>
</template>
