import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// 「ページが見つかりません」の部品 (エラーの画面と旅行の詳細で使う) を確かめる (Issue #175)。
const source = readFileSync("app/components/NotFoundMessage.vue", "utf8")
const root = parse(source).descriptor.template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

function attr(node, name) {
  return node.props.find((p) => p.type === 6 && p.name === name)?.value?.content
}

function text(node) {
  return (node.children || []).map((child) => (child.type === 2 ? child.content : text(child))).join("").trim()
}

describe("components/NotFoundMessage.vue", () => {
  it("says the page was not found in Japanese", () => {
    expect(elements(root, "h1").map(text)).toEqual(["ページが見つかりません"])
  })

  it("links back to the top", () => {
    const link = elements(root, "NuxtLink").find((e) => attr(e, "to") === "/")
    expect(text(link)).toBe("トップへ戻る")
  })
})
