import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// 存在しない旅行を開いたときに、API の生の文言を出さないことを確かめる (Issue #175)。
const source = readFileSync("app/pages/trips/[id]/index.vue", "utf8")
const root = parse(source).descriptor.template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

describe("pages/trips/[id]/index.vue", () => {
  it("shows the not found message for 404", () => {
    const message = elements(root, "NotFoundMessage")[0]
    const condition = message.props.find((p) => p.type === 7 && p.name === "else-if")?.exp?.content
    expect(condition).toContain("404")
  })

  it("does not show the raw error message", () => {
    expect(parse(source).descriptor.template.content).not.toContain("error.message")
  })
})
