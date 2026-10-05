import { describe, it, expect, beforeAll } from "vitest"

// URL を貼ったときのプレビューに使う説明文と OGP を確かめる (Issue #169)。
// 画面はビルドのときに作るので、og:image と og:url は絶対 URL でないとプレビューに使われない。
let meta

beforeAll(async () => {
  globalThis.defineNuxtConfig = (config) => config
  const config = (await import("../../nuxt.config.js")).default
  meta = config.app.head.meta
})

function content(key) {
  return meta.find((m) => m.name === key || m.property === key)?.content
}

describe("nuxt.config app.head", () => {
  it("has a description and OGP tags", () => {
    for (const key of ["description", "og:title", "og:description", "og:image", "og:url", "twitter:card"]) {
      expect(content(key), key).toBeTruthy()
    }
  })

  it("uses absolute https URLs for og:image and og:url", () => {
    expect(content("og:image").startsWith("https://")).toBe(true)
    expect(content("og:url").startsWith("https://")).toBe(true)
  })
})
