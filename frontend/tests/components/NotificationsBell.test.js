import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// 件数を取る前に「0 件未読」と読み上げないことを確かめる (Issue #187)。
const source = readFileSync("app/components/NotificationsBell.vue", "utf8")
const { template, scriptSetup } = parse(source).descriptor

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

describe("components/NotificationsBell.vue", () => {
  it("names the bell without the count until the count is loaded", () => {
    const button = elements(template.ast, "MenuButton")[0]
    const label = button.props.find((p) => p.type === 7 && p.name === "bind" && p.arg?.content === "aria-label")
    expect(label.exp.content).toBe("bellLabel")
    expect(scriptSetup.content).toContain("store.countLoaded")
  })
})
