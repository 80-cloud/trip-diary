import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// ヘッダーの小さいボタンだけ、狭い幅で文言を短くすることを確かめる (Issue #172)。
// 文言を短くしても、ボタンの名前はどの幅でも変えない (Issue #205)。
// 見える文字は、どの幅でも名前に含まれる (WCAG 2.5.3・Issue #209)。
const source = readFileSync("app/components/GuestLoginButton.vue", "utf8")
const { template, scriptSetup } = parse(source).descriptor
const root = template.ast

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
  it("shows a short label on narrow screens but keeps one name that contains it", () => {
    const spans = elements(root, "span")
    const short = spans.find((e) => attr(e, "class") === "sm:hidden")
    const full = spans.find((e) => attr(e, "class") === "hidden sm:inline")
    expect(text(short)).toBe("ゲストで試す")
    expect(text(full)).toBe("ゲストで試す (登録不要)")
    const button = elements(root, "button")[0]
    const label = button.props.find((p) => p.type === 7 && p.name === "bind" && p.arg?.content === "aria-label")
    expect(label.exp.content).toBe("ariaLabel")
    const name = scriptSetup.content.match(/const headerLabel = "(.+)"/)[1]
    expect(name).toBe("ゲストで試す (登録不要)")
    expect(name).toContain(text(short))
    expect(name).toContain(text(full))
  })
})
