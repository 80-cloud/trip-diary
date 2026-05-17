<script setup>
import { CATEGORY_OPTIONS } from "~/composables/useCategories.js"

const props = defineProps({
  initial: { type: Object, default: null },
  errors: { type: Array, default: () => [] }
})
const emit = defineEmits(["submit"])

const title = ref(props.initial?.title || "")
const destination = ref(props.initial?.destination || "")
const startedOn = ref(props.initial?.started_on || "")
const endedOn = ref(props.initial?.ended_on || "")
const body = ref(props.initial?.body || "")
const visibility = ref(props.initial?.visibility || "public")
const category = ref(props.initial?.category || "")
const tagInput = ref((props.initial?.tags || []).join(", "))

function parseTagList(text) {
  return (text || "")
    .split(/[,、]/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
}

const dayEntries = ref(
  props.initial?.day_entries?.length
    ? props.initial.day_entries.map((d) => ({ ...d }))
    : []
)

const selectedFiles = ref([])
const localError = ref(null)
const MAX_IMAGES = 5
const MAX_SIZE_MB = 5

function onFilesChange(e) {
  localError.value = null
  const files = Array.from(e.target.files || [])
  if (files.length > MAX_IMAGES) {
    localError.value = `画像は最大 ${MAX_IMAGES} 枚までです`
    e.target.value = ""
    selectedFiles.value = []
    return
  }
  const tooLarge = files.find((f) => f.size > MAX_SIZE_MB * 1024 * 1024)
  if (tooLarge) {
    localError.value = `各画像は ${MAX_SIZE_MB}MB 以下にしてください (${tooLarge.name})`
    e.target.value = ""
    selectedFiles.value = []
    return
  }
  selectedFiles.value = files
}

function addDay() {
  dayEntries.value.push({
    day_number: dayEntries.value.length + 1,
    happened_on: "",
    title: "",
    body: "",
    position: dayEntries.value.length
  })
}

function removeDay(idx) {
  const d = dayEntries.value[idx]
  if (d.id) {
    d._destroy = true
  } else {
    dayEntries.value.splice(idx, 1)
  }
}

const visibleDayEntries = computed(() =>
  dayEntries.value.map((d, idx) => ({ ...d, _idx: idx })).filter((d) => !d._destroy)
)

function submit() {
  const tagList = parseTagList(tagInput.value)
  // 画像がある場合は multipart/form-data、ない場合は JSON で送信
  if (selectedFiles.value.length > 0) {
    const fd = new FormData()
    fd.append("title", title.value)
    fd.append("destination", destination.value)
    fd.append("started_on", startedOn.value)
    fd.append("ended_on", endedOn.value)
    fd.append("body", body.value)
    fd.append("visibility", visibility.value)
    fd.append("category", category.value)
    // 空配列でも Rails 側で「全タグ外し」を意図するため、必ず空配列フィールドを送る
    if (tagList.length === 0) {
      fd.append("tag_list[]", "")
    } else {
      tagList.forEach((t) => fd.append("tag_list[]", t))
    }
    dayEntries.value.forEach((d, i) => {
      const prefix = `day_entries_attributes[${i}]`
      if (d.id) fd.append(`${prefix}[id]`, d.id)
      fd.append(`${prefix}[day_number]`, d.day_number || i + 1)
      fd.append(`${prefix}[happened_on]`, d.happened_on || "")
      fd.append(`${prefix}[title]`, d.title || "")
      fd.append(`${prefix}[body]`, d.body || "")
      fd.append(`${prefix}[position]`, i)
      if (d._destroy) fd.append(`${prefix}[_destroy]`, "1")
    })
    selectedFiles.value.forEach((f) => fd.append("images[]", f))
    emit("submit", fd)
  } else {
    emit("submit", {
      title: title.value,
      destination: destination.value,
      started_on: startedOn.value,
      ended_on: endedOn.value,
      body: body.value,
      visibility: visibility.value,
      category: category.value,
      tag_list: tagList,
      day_entries_attributes: dayEntries.value.map((d, i) => ({
        ...d,
        day_number: d.day_number || i + 1,
        position: i
      }))
    })
  }
}
</script>

<template>
  <form @submit.prevent="submit" class="bg-white p-6 rounded-lg border border-slate-200 space-y-4 max-w-3xl">
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1">タイトル *</label>
      <input v-model="title" required maxlength="80" class="w-full border border-slate-300 rounded px-3 py-2" />
    </div>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1">行き先 *</label>
      <input v-model="destination" required maxlength="80" class="w-full border border-slate-300 rounded px-3 py-2" />
    </div>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">開始日 *</label>
        <input v-model="startedOn" type="date" required class="w-full border border-slate-300 rounded px-3 py-2" />
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">終了日 *</label>
        <input v-model="endedOn" type="date" required class="w-full border border-slate-300 rounded px-3 py-2" />
      </div>
    </div>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1">本文 (任意・5000 文字以内)</label>
      <textarea v-model="body" rows="4" maxlength="5000" class="w-full border border-slate-300 rounded px-3 py-2"></textarea>
    </div>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1">
        画像 (任意・最大 {{ MAX_IMAGES }} 枚・各 {{ MAX_SIZE_MB }}MB 以下)
      </label>
      <input
        type="file" accept="image/*" multiple @change="onFilesChange"
        class="block w-full text-sm text-slate-600 file:mr-3 file:py-1.5 file:px-3 file:rounded file:border-0 file:text-sm file:bg-brand-50 file:text-brand-700 hover:file:bg-brand-100"
      />
      <p v-if="selectedFiles.length" class="text-xs text-slate-500 mt-1">
        選択中: {{ selectedFiles.map((f) => f.name).join(", ") }}
      </p>
      <p v-if="localError" class="text-xs text-rose-600 mt-1">{{ localError }}</p>
      <p v-if="props.initial?.image_urls?.length" class="text-xs text-slate-400 mt-1">
        ※ 既存の画像は新しく選択した画像で置き換わります
      </p>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">カテゴリ *</label>
        <select v-model="category" required class="w-full border border-slate-300 rounded px-3 py-2">
          <option value="" disabled>選択してください</option>
          <option v-for="opt in CATEGORY_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">公開範囲</label>
        <select v-model="visibility" class="w-full border border-slate-300 rounded px-3 py-2">
          <option value="public">公開 (全員)</option>
          <option value="friends">フォロワーのみ (Phase 2)</option>
          <option value="private">非公開 (自分のみ)</option>
        </select>
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1">タグ (任意・カンマ区切り)</label>
      <input
        v-model="tagInput" maxlength="200" placeholder="例: 京都, 紅葉, 寺"
        class="w-full border border-slate-300 rounded px-3 py-2"
      />
      <p class="text-xs text-slate-500 mt-1">複数指定するときは「,」または「、」で区切ってください</p>
    </div>

    <fieldset class="border-t pt-4">
      <legend class="text-sm font-bold text-slate-800">日別の出来事</legend>
      <div v-for="d in visibleDayEntries" :key="d.id || `new-${d._idx}`" class="bg-slate-50 p-3 rounded mt-2 space-y-2">
        <div class="flex items-center justify-between">
          <span class="text-xs text-slate-500">Day {{ d._idx + 1 }}</span>
          <button type="button" @click="removeDay(d._idx)" class="text-xs text-rose-500 hover:underline">削除</button>
        </div>
        <input v-model="dayEntries[d._idx].title" placeholder="タイトル *" required maxlength="80"
          class="w-full border border-slate-300 rounded px-2 py-1 text-sm" />
        <div class="flex gap-2">
          <input v-model="dayEntries[d._idx].happened_on" type="date" class="border border-slate-300 rounded px-2 py-1 text-sm" />
        </div>
        <textarea v-model="dayEntries[d._idx].body" rows="2" placeholder="メモ (任意)"
          class="w-full border border-slate-300 rounded px-2 py-1 text-sm"></textarea>
      </div>
      <button type="button" @click="addDay" class="mt-3 text-sm text-brand-600 hover:underline">+ 出来事を追加</button>
    </fieldset>

    <ul v-if="errors.length" class="text-sm text-rose-600 list-disc list-inside">
      <li v-for="err in errors" :key="err">{{ err }}</li>
    </ul>

    <div class="flex items-center justify-end gap-2 border-t pt-4">
      <NuxtLink to="/" class="px-4 py-2 text-sm text-slate-600 hover:underline">キャンセル</NuxtLink>
      <button type="submit" class="bg-brand-500 text-white px-6 py-2 rounded font-medium hover:bg-brand-600">
        保存
      </button>
    </div>
  </form>
</template>
