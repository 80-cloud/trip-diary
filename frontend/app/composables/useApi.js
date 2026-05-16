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

  async function request(path, options = {}) {
    return await $fetch(path, buildOptions(options.method || "GET", options))
  }

  return {
    get:  (p, o = {}) => request(p, { method: "GET",    ...o }),
    post: (p, o = {}) => request(p, { method: "POST",   ...o }),
    put:  (p, o = {}) => request(p, { method: "PUT",    ...o }),
    patch:(p, o = {}) => request(p, { method: "PATCH",  ...o }),
    del:  (p, o = {}) => request(p, { method: "DELETE", ...o })
  }
}
