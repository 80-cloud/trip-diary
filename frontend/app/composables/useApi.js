import { useAuthStore } from "~/composables/useAuthStore.js"
import { useNotificationsStore } from "~/composables/useNotificationsStore.js"

export function useApi() {
  const config = useRuntimeConfig()
  const base = config.public.apiBase

  function buildOptions(method, options) {
    const opts = {
      baseURL: base,
      credentials: "include",
      method,
      ...options
    }
    // body が plain object なら JSON で送る。FormData / File はそのまま渡し、Content-Type は fetch に任せる。
    if (opts.body && !(opts.body instanceof FormData) && typeof opts.body === "object") {
      opts.headers = { "Content-Type": "application/json", ...(opts.headers || {}) }
    }
    return opts
  }

  // ログインが切れた (401) ときは、画面のログイン状態と通知を空にする。
  // fetched は true のままにして、GET /me を取り直さない。
  function clearSession() {
    useAuthStore().user = null
    useNotificationsStore().reset()
  }

  async function request(path, options = {}) {
    try {
      return await $fetch(path, buildOptions(options.method || "GET", options))
    } catch (error) {
      if (error?.statusCode === 401) clearSession()
      // 各画面のエラー表示はそのまま使うので、元のエラーを投げ直す
      throw error
    }
  }

  return {
    get:  (p, o = {}) => request(p, { method: "GET",    ...o }),
    post: (p, o = {}) => request(p, { method: "POST",   ...o }),
    put:  (p, o = {}) => request(p, { method: "PUT",    ...o }),
    patch:(p, o = {}) => request(p, { method: "PATCH",  ...o }),
    del:  (p, o = {}) => request(p, { method: "DELETE", ...o })
  }
}
