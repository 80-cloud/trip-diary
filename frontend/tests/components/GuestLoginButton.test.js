import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// ヘッダーの小さいボタンだけ、狭い幅で文言を短くすることを確かめる (Issue #172)。
const source = readFileSync("app/components/GuestLoginButton.vue", "utf8")
const root = parse(source).descriptor.template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

function attr(node, name) {
  return node.props.find((p) => p.type === 6 && p.name === name)?.value?.content
}

function text(node) {
  return (node.children || []).map((child) => (child.type === 2 ? child.content : text(child))).join("")
}

describe("components/GuestLoginButton.vue", () => {
  it("shows a short label on narrow screens", () => {
    const spans = elements(root, "span")
    const short = spans.find((e) => attr(e, "class") === "sm:hidden")
    const full = spans.find((e) => attr(e, "class") === "hidden sm:inline")
    expect(text(short)).toBe("ゲストで試す")
    expect(text(full)).toBe("ゲストとして試す (登録不要)")
  })
})
