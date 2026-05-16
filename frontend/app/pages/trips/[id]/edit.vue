<script setup>
import TripForm from "~/components/TripForm.vue"

definePageMeta({ middleware: "auth" })

const route = useRoute()
const router = useRouter()
const api = useApi()
const id = route.params.id

const { data: trip } = await useAsyncData(`trip-edit-${id}`, () => api.get(`/trips/${id}`))
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
    <h1 class="text-2xl font-bold text-slate-800 mb-6">旅行記録を編集</h1>
    <TripForm v-if="trip" :initial="trip" @submit="submit" :errors="errors" />
  </div>
</template>
