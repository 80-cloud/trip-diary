<script setup>
import TripForm from "~/components/TripForm.vue"

definePageMeta({ middleware: "auth" })

const api = useApi()
const router = useRouter()
const errors = ref([])

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
    <TripForm @submit="submit" :errors="errors" />
  </div>
</template>
