<script setup>
import { useAuthStore } from "~/composables/useAuthStore.js"
import ImageCropperModal from "~/components/ImageCropperModal.vue"

const route = useRoute()
const api = useApi()
const config = useRuntimeConfig()
const auth = useAuthStore()

const id = route.params.id
const tab = ref(route.query.tab === "followers" ? "followers" : "following")

const { data: list } = await useAsyncData(
  () => `users-${id}-${tab.value}`,
  () => api.get(`/users/${id}/follows`, { params: { type: tab.value } }),
  { watch: [tab], deep: true }
)

const { data: tripsRes } = await useAsyncData(
  `users-${id}-trips`,
  () => api.get("/trips", { params: { user_id: id, limit: 20 } }),
  { deep: true }
)
const trips = computed(() => tripsRes.value?.trips || [])

function fullImageUrl(path) {
  if (!path) return null
  if (path.startsWith("http")) return path
  const base = config.public.apiBase.replace(/\/api\/v1$/, "")
  return base + path
}

// プロフィール表示用: 自分自身なら auth.user / 他人なら trip レスポンスから
const isSelf = computed(() => auth.user && Number(auth.user.id) === Number(id))
const profileUser = computed(() => isSelf.value ? auth.user : trips.value[0]?.user)
const profileName = computed(() => profileUser.value?.display_name || `User #${id}`)
const profileBio  = computed(() => profileUser.value?.bio || "")
const profileAvatar = computed(() => profileUser.value?.avatar_url)

// 編集モード (自分のみ)
const editing = ref(false)
const editDisplayName = ref("")
const editBio = ref("")
const editAvatarFile = ref(null)
const editError = ref(null)
const editSaving = ref(false)

function openEdit() {
  editDisplayName.value = auth.user.display_name || ""
  editBio.value = auth.user.bio || ""
  editAvatarFile.value = null
  editError.value = null
  editing.value = true
}

const avatarCropFile = ref(null)
const avatarInputEl = ref(null)
function onAvatarChange(e) {
  const f = e.target.files?.[0] || null
  avatarInputEl.value = e.target
  if (f && f.size > 2 * 1024 * 1024) {
    editError.value = "画像は 2MB 以下にしてください"
    editAvatarFile.value = null
    e.target.value = ""
    return
  }
  editError.value = null
  // クロップモーダルへ。確定したら editAvatarFile に入る
  avatarCropFile.value = f
}
function onAvatarCropConfirm(file) {
  editAvatarFile.value = file
  avatarCropFile.value = null
}
function onAvatarCropCancel() {
  avatarCropFile.value = null
  editAvatarFile.value = null
  if (avatarInputEl.value) avatarInputEl.value.value = ""
}

async function saveProfile() {
  editError.value = null
  editSaving.value = true
  try {
    let body
    if (editAvatarFile.value) {
      body = new FormData()
      body.append("display_name", editDisplayName.value)
      body.append("bio", editBio.value)
      body.append("avatar", editAvatarFile.value)
    } else {
      body = { display_name: editDisplayName.value, bio: editBio.value }
    }
    const res = await api.patch("/me", { body })
    auth.user = res.user
    editing.value = false
  } catch (e) {
    editError.value = e.data?.errors?.join(", ") || "プロフィール保存に失敗しました"
  } finally {
    editSaving.value = false
  }
}
</script>

<template>
  <div>
    <NuxtLink to="/" class="text-sm text-brand-600 dark:text-brand-50 hover:underline">← タイムラインに戻る</NuxtLink>

    <!-- プロフィールカード -->
    <section class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-6 mt-4 mb-6">
      <div class="flex items-start gap-4">
        <div class="shrink-0">
          <img
            v-if="profileAvatar"
            :src="fullImageUrl(profileAvatar)"
            :alt="profileName"
            class="w-20 h-20 rounded-full object-cover bg-slate-100 dark:bg-slate-700"
          />
          <div v-else class="w-20 h-20 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center text-2xl text-slate-500 dark:text-slate-400">
            👤
          </div>
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between gap-2">
            <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100 truncate">@{{ profileName }}</h1>
            <button
              v-if="isSelf && !editing"
              @click="openEdit"
              class="shrink-0 text-xs bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 px-3 py-1.5 rounded hover:bg-slate-200 dark:hover:bg-slate-600"
            >プロフィールを編集</button>
          </div>
          <p v-if="profileBio" class="text-sm text-slate-600 dark:text-slate-300 mt-2 whitespace-pre-wrap">{{ profileBio }}</p>
          <p v-else-if="isSelf && !editing" class="text-xs text-slate-400 dark:text-slate-500 mt-2">自己紹介はまだ未設定です</p>
        </div>
      </div>

      <!-- 編集フォーム (本人のみ) -->
      <form v-if="isSelf && editing" @submit.prevent="saveProfile" class="mt-4 space-y-3 border-t border-slate-200 dark:border-slate-700 pt-4">
        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">表示名 *</label>
          <input
            v-model="editDisplayName" required maxlength="30"
            class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 rounded px-3 py-2"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">自己紹介 (500 字以内)</label>
          <textarea
            v-model="editBio" rows="3" maxlength="500"
            class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 rounded px-3 py-2"
          ></textarea>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200 mb-1">アバター (JPEG / PNG / GIF / WebP / 2MB 以下)</label>
          <input
            id="user-avatar-input"
            type="file" accept="image/*" @change="onAvatarChange"
            class="absolute w-0 h-0 opacity-0 pointer-events-none -z-10"
          />
          <div class="flex items-center gap-3 flex-wrap">
            <label
              for="user-avatar-input"
              class="inline-block cursor-pointer bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 px-4 py-1.5 rounded text-sm font-medium hover:bg-slate-300 dark:hover:bg-slate-600"
            >ファイルを選択</label>
            <span v-if="editAvatarFile" class="text-xs text-slate-600 dark:text-slate-300 truncate">{{ editAvatarFile.name }}</span>
          </div>
        </div>
        <p v-if="editError" class="text-sm text-rose-600">{{ editError }}</p>
        <div class="flex items-center gap-2 justify-end">
          <button type="button" @click="editing = false" class="text-sm text-slate-500 dark:text-slate-400 hover:underline">キャンセル</button>
          <button type="submit" :disabled="editSaving"
            class="bg-brand-500 text-white px-4 py-1.5 rounded text-sm hover:bg-brand-600 disabled:opacity-50">
            {{ editSaving ? "保存中…" : "保存" }}
          </button>
        </div>
      </form>
    </section>

    <!-- フォロー/フォロワータブ -->
    <div class="flex gap-1 mb-4 border-b border-slate-200 dark:border-slate-700">
      <button
        type="button" @click="tab = 'following'"
        :class="[
          'px-4 py-2 text-sm border-b-2 -mb-px',
          tab === 'following' ? 'border-brand-500 text-brand-600 dark:text-brand-50 font-bold' : 'border-transparent text-slate-500 dark:text-slate-400'
        ]"
      >フォロー中</button>
      <button
        type="button" @click="tab = 'followers'"
        :class="[
          'px-4 py-2 text-sm border-b-2 -mb-px',
          tab === 'followers' ? 'border-brand-500 text-brand-600 dark:text-brand-50 font-bold' : 'border-transparent text-slate-500 dark:text-slate-400'
        ]"
      >フォロワー</button>
    </div>

    <section class="mb-6">
      <ul v-if="list && list.length" class="divide-y divide-slate-200 dark:divide-slate-700 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700">
        <li v-for="u in list" :key="u.id" class="p-3 flex items-center justify-between">
          <NuxtLink :to="`/users/${u.id}`" class="text-sm text-slate-700 dark:text-slate-200 hover:underline">@{{ u.display_name }}</NuxtLink>
          <span v-if="u.followed_by_me" class="text-[10px] px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400">フォロー中</span>
        </li>
      </ul>
      <p v-else class="text-sm text-slate-500 dark:text-slate-400">{{ tab === "following" ? "フォロー中のユーザーはいません" : "フォロワーはいません" }}</p>
    </section>

    <h2 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3">投稿した旅行記録</h2>
    <div v-if="trips.length === 0" class="text-sm text-slate-500 dark:text-slate-400">公開された旅行記録はありません</div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <NuxtLink
        v-for="t in trips" :key="t.id" :to="`/trips/${t.id}`"
        class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden hover:shadow-md flex flex-col"
      >
        <div class="aspect-video bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-300 dark:text-slate-500">
          <img v-if="t.image_url" :src="fullImageUrl(t.image_url)" class="w-full h-full object-cover" :alt="t.title" />
          <span v-else class="text-4xl">📷</span>
        </div>
        <div class="p-4 flex-1">
          <h3 class="font-bold text-slate-800 dark:text-slate-100 line-clamp-1">{{ t.title }}</h3>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">{{ t.started_on }} 〜 {{ t.ended_on }}</p>
        </div>
      </NuxtLink>
    </div>
  </div>
  <ImageCropperModal
    v-if="avatarCropFile"
    :file="avatarCropFile"
    :filename="avatarCropFile?.name || 'avatar.jpg'"
    @confirm="onAvatarCropConfirm"
    @cancel="onAvatarCropCancel"
  />
</template>
