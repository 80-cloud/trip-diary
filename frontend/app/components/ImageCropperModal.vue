<script setup>
import { Cropper } from "vue-advanced-cropper"
import "vue-advanced-cropper/dist/style.css"

const props = defineProps({
  file: { type: Object, default: null }, // File or Blob (image only)
  filename: { type: String, default: "cropped.jpg" }
})
const emit = defineEmits(["confirm", "cancel"])

const cropperRef = ref(null)
const imageSrc = ref(null)

// File → blob URL (img src)。プロップ変更で都度差し替え。
watch(() => props.file, (f) => {
  if (imageSrc.value) URL.revokeObjectURL(imageSrc.value)
  imageSrc.value = f ? URL.createObjectURL(f) : null
}, { immediate: true })

onBeforeUnmount(() => {
  if (imageSrc.value) URL.revokeObjectURL(imageSrc.value)
})

// 「適用」: 現在の枠で切り取って Blob を作って親に返す。元ファイルの mime を維持。
function confirm() {
  if (!cropperRef.value) return
  const { canvas } = cropperRef.value.getResult()
  if (!canvas) return
  const type = props.file?.type || "image/jpeg"
  canvas.toBlob((blob) => {
    if (!blob) return
    // File にして渡すと既存の FormData append がそのまま動く
    const out = new File([blob], props.filename, { type })
    emit("confirm", out)
  }, type, 0.92)
}
</script>

<template>
  <Teleport to="body">
    <div v-if="imageSrc" class="fixed inset-0 z-50 bg-black/80 flex flex-col" role="dialog" aria-modal="true">
      <header class="flex items-center justify-between px-4 py-3 text-white">
        <span class="text-sm">画像を切り抜き (ドラッグで範囲調整・自由比率)</span>
        <div class="flex items-center gap-2">
          <button type="button" @click="emit('cancel')" class="text-sm px-3 py-1.5 rounded bg-slate-700 hover:bg-slate-600">キャンセル</button>
          <button type="button" @click="confirm" class="text-sm px-3 py-1.5 rounded bg-brand-500 hover:bg-brand-600">適用</button>
        </div>
      </header>
      <div class="flex-1 min-h-0 px-4 pb-4">
        <Cropper
          ref="cropperRef"
          :src="imageSrc"
          class="w-full h-full bg-black"
          :stencil-props="{ aspectRatio: undefined }"
        />
      </div>
    </div>
  </Teleport>
</template>
