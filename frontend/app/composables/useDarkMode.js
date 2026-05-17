// F-UI-DARK: ダークモードの状態管理
// 優先順位:
//   1. localStorage("trip-diary:theme") の保存値 ("dark" | "light")
//   2. prefers-color-scheme: dark のメディアクエリ
//   3. light (フォールバック)
//
// SSR-safe: window/document/localStorage は onMounted 後でのみ触る (Nuxt 4 SSR=false でも安全側)

const STORAGE_KEY = "trip-diary:theme"

function applyTheme(theme) {
  if (typeof document === "undefined") return
  const root = document.documentElement
  if (theme === "dark") {
    root.classList.add("dark")
  } else {
    root.classList.remove("dark")
  }
}

function resolveInitial() {
  if (typeof window === "undefined") return "light"
  const saved = window.localStorage?.getItem(STORAGE_KEY)
  if (saved === "dark" || saved === "light") return saved
  if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) return "dark"
  return "light"
}

export function useDarkMode() {
  const theme = useState("dark-mode-theme", () => "light")
  const isDark = computed(() => theme.value === "dark")

  onMounted(() => {
    theme.value = resolveInitial()
    applyTheme(theme.value)
  })

  function toggle() {
    theme.value = isDark.value ? "light" : "dark"
    applyTheme(theme.value)
    if (typeof window !== "undefined") {
      window.localStorage?.setItem(STORAGE_KEY, theme.value)
    }
  }

  function setTheme(next) {
    if (next !== "dark" && next !== "light") return
    theme.value = next
    applyTheme(next)
    if (typeof window !== "undefined") {
      window.localStorage?.setItem(STORAGE_KEY, next)
    }
  }

  return { isDark, theme: readonly(theme), toggle, setTheme }
}

// テスト用にエクスポート (Vitest からの直接呼び出しで挙動確認)
export const __internal = { STORAGE_KEY, resolveInitial, applyTheme }
