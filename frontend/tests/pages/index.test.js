import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// トップの画面の見出しと、入力欄の名前を確かめる (Issue #169)。
// 画面を描くと Nuxt の部品やデータの読み込みが要るので、テンプレートの構造を読んで確かめる。
// パスは frontend からの相対 (テストの環境 happy-dom では import.meta.url が file: にならない)。
const source = readFileSync("app/pages/index.vue", "utf8")
const root = parse(source).descriptor.template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

function attr(node, name) {
  return node.props.find((p) => p.type === 6 && p.name === name)?.value?.content
}

describe("pages/index.vue", () => {
  it("has exactly one h1", () => {
    expect(elements(root, "h1")).toHaveLength(1)
  })

  it("names the search field with id, name and aria-label", () => {
    const search = elements(root, "input").find((e) => attr(e, "type") === "search")
    expect(attr(search, "id")).toBeTruthy()
    expect(attr(search, "name")).toBeTruthy()
    expect(attr(search, "aria-label")).toBeTruthy()
  })

  it("names the sort select with id, name and aria-label", () => {
    const selects = elements(root, "select")
    expect(selects).toHaveLength(1)
    expect(attr(selects[0], "id")).toBeTruthy()
    expect(attr(selects[0], "name")).toBeTruthy()
    expect(attr(selects[0], "aria-label")).toBeTruthy()
  })
})
