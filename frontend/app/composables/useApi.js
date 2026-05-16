export function useApi() {
  const config = useRuntimeConfig()
  const base = config.public.apiBase

  async function request(path, options = {}) {
    const opts = {
      baseURL: base,
      credentials: "include",
      ...options
    }
    return await $fetch(path, opts)
  }

  return {
    get:  (p, o = {}) => request(p, { method: "GET",    ...o }),
    post: (p, o = {}) => request(p, { method: "POST",   ...o }),
    put:  (p, o = {}) => request(p, { method: "PUT",    ...o }),
    patch:(p, o = {}) => request(p, { method: "PATCH",  ...o }),
    del:  (p, o = {}) => request(p, { method: "DELETE", ...o })
  }
}
