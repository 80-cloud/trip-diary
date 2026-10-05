import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// 存在しない URL などで出るエラーの画面を確かめる (Issue #175)。
// 404 のときは日本語の「ページが見つかりません」を出し、ヘッダー付きの画面からトップへ戻れるようにする。
const source = readFileSync("app/error.vue", "utf8")
const { template, scriptSetup } = parse(source).descriptor
const root = template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

function attr(node, name) {
  return node.props.find((p) => p.type === 6 && p.name === name)?.value?.content
}

function directive(node, name) {
  return node.props.find((p) => p.type === 7 && p.name === name)
}

describe("app/error.vue", () => {
  it("keeps the header by wrapping the page in the layout", () => {
    expect(root.children.filter((c) => c.type === 1).map((c) => c.tag)).toEqual(["NuxtLayout"])
  })

  it("shows the not found message for 404", () => {
    const message = elements(root, "NotFoundMessage")[0]
    expect(directive(message, "if")?.exp?.content).toBe("notFound")
    expect(scriptSetup.content).toMatch(/=== 404/)
  })

  // SPA のため HTTP は 200 を返すので、404 の画面は検索エンジンに登録させない (Issue #194)
  it("asks search engines not to index the not found page", () => {
    expect(scriptSetup.content).toContain(`notFound.value ? [{ name: "robots", content: "noindex" }] : []`)
  })

  it("links back to the top on other errors", () => {
    const links = elements(root, "NuxtLink").filter((e) => attr(e, "to") === "/")
    expect(links.length).toBeGreaterThan(0)
  })
})
