import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// スマホの幅でヘッダーが崩れないための指定と、ボタンの名前を確かめる (Issue #172)。
// 見た目は DevTools で確かめ、ここではテンプレートの構造を読む (手本は tests/pages/index.test.js)。
const source = readFileSync("app/layouts/default.vue", "utf8")
const root = parse(source).descriptor.template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

function attr(node, name) {
  return node.props.find((p) => p.type === 6 && p.name === name)?.value?.content
}

function bound(node, name) {
  return node.props.find((p) => p.type === 7 && p.arg?.content === name)?.exp?.content
}

// template (v-if など) をほどいて、nav に並ぶ要素を取り出す
function items(node) {
  return node.children
    .filter((child) => child.type === 1)
    .flatMap((child) => (child.tag === "template" ? items(child) : [child]))
}

const nav = elements(root, "nav")[0]
const links = elements(root, "NuxtLink")

describe("layouts/default.vue", () => {
  it("keeps every header item on one line", () => {
    for (const item of items(nav)) {
      expect(attr(item, "class"), item.tag).toContain("shrink-0")
    }
  })

  it("names the logo link even when its text is hidden", () => {
    const logo = links.find((e) => attr(e, "to") === "/")
    expect(attr(logo, "aria-label")).toBe("trip-diary")
  })

  it("shortens the new trip link on narrow screens", () => {
    const link = links.find((e) => bound(e, "to") === "newTripTo")
    expect(attr(link, "aria-label")).toBe("新しい旅行記録")
    const spans = elements(link, "span").map((e) => attr(e, "class"))
    expect(spans).toContain("sm:hidden")
    expect(spans).toContain("hidden sm:inline")
  })

  it("hides the signup link on narrow screens", () => {
    const link = links.find((e) => attr(e, "to") === "/signup")
    expect(attr(link, "class")).toContain("hidden sm:inline-block")
  })

  it("names the favorites link", () => {
    const link = links.find((e) => attr(e, "to") === "/favorites")
    expect(attr(link, "aria-label")).toBe("お気に入り")
  })

  it("keeps the logout button named and not a submit button", () => {
    const button = elements(root, "button").find((e) =>
      e.props.some((p) => p.type === 7 && p.arg?.content === "click" && p.exp?.content === "logout"))
    expect(attr(button, "type")).toBe("button")
    expect(attr(button, "aria-label")).toBe("ログアウト")
  })
})
