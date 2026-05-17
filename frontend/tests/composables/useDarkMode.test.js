import { describe, it, expect, beforeEach } from "vitest"
import { __internal } from "~/composables/useDarkMode.js"

const { STORAGE_KEY, resolveInitial, applyTheme } = __internal

// happy-dom の localStorage はメソッドが揃っていないため自前で stub する。
// （`--localstorage-file` 警告で示されるとおり、happy-dom の Storage 実装は不完全）
function installFakeLocalStorage() {
  const store = new Map()
  Object.defineProperty(window, "localStorage", {
    configurable: true,
    value: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
      removeItem: (k) => store.delete(k),
      clear: () => store.clear()
    }
  })
}

function fakeMatchMedia(prefersDark) {
  return () => ({ matches: prefersDark, media: "", addListener: () => {}, removeListener: () => {} })
}

describe("useDarkMode (internal)", () => {
  beforeEach(() => {
    installFakeLocalStorage()
    document.documentElement.classList.remove("dark")
  })

  describe("resolveInitial", () => {
    it("localStorage に 'dark' が保存されていれば優先する", () => {
      window.localStorage.setItem(STORAGE_KEY, "dark")
      window.matchMedia = fakeMatchMedia(false)
      expect(resolveInitial()).toBe("dark")
    })

    it("localStorage に 'light' が保存されていれば優先する", () => {
      window.localStorage.setItem(STORAGE_KEY, "light")
      window.matchMedia = fakeMatchMedia(true)
      expect(resolveInitial()).toBe("light")
    })

    it("保存値がなければ prefers-color-scheme: dark に従う", () => {
      window.matchMedia = fakeMatchMedia(true)
      expect(resolveInitial()).toBe("dark")
    })

    it("保存値もメディアクエリも無ければ light", () => {
      window.matchMedia = fakeMatchMedia(false)
      expect(resolveInitial()).toBe("light")
    })

    it("localStorage に不正値があれば無視して media に従う", () => {
      window.localStorage.setItem(STORAGE_KEY, "blue")
      window.matchMedia = fakeMatchMedia(true)
      expect(resolveInitial()).toBe("dark")
    })
  })

  describe("applyTheme", () => {
    it("'dark' で html.dark を付与", () => {
      applyTheme("dark")
      expect(document.documentElement.classList.contains("dark")).toBe(true)
    })

    it("'light' で html.dark を外す", () => {
      document.documentElement.classList.add("dark")
      applyTheme("light")
      expect(document.documentElement.classList.contains("dark")).toBe(false)
    })
  })
})
