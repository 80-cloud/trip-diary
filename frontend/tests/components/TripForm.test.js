import { describe, it, expect } from "vitest"
import { readFileSync } from "node:fs"
import { parse } from "vue/compiler-sfc"

// スマホの幅で作成画面のボタンと選択欄が崩れないことと、ゲストに公開範囲を出さないことを確かめる (Issue #172)。
const source = readFileSync("app/components/TripForm.vue", "utf8")
const root = parse(source).descriptor.template.ast

function elements(node, tag) {
  const found = node.type === 1 && node.tag === tag ? [node] : []
  return found.concat((node.children || []).flatMap((child) => elements(child, tag)))
}

function attr(node, name) {
  return node.props.find((p) => p.type === 6 && p.name === name)?.value?.content
}

function directive(node, name, arg) {
  return node.props.find((p) => p.type === 7 && p.name === name && (arg === undefined || p.arg?.content === arg))?.exp?.content
}

function parentOf(node, target) {
  for (const child of node.children || []) {
    if (child === target) return node
    const found = parentOf(child, target)
    if (found) return found
  }
  return null
}

const selects = elements(root, "select")
const category = selects.find((e) => directive(e, "model") === "category")
const visibility = selects.find((e) => directive(e, "model") === "visibility")

const FIELDS = {
  title: "trip-title",
  destination: "trip-destination",
  startedOn: "trip-started-on",
  endedOn: "trip-ended-on",
  body: "trip-body",
  tagInput: "trip-tags",
}

describe("components/TripForm.vue", () => {
  it("links each input to its label", () => {
    const labels = elements(root, "label").map((e) => attr(e, "for"))
    const fields = [...elements(root, "input"), ...elements(root, "textarea")]
    for (const [model, id] of Object.entries(FIELDS)) {
      const field = fields.find((e) => directive(e, "model") === model)
      expect(attr(field, "id"), model).toBe(id)
      expect(labels, model).toContain(id)
    }
  })

  // 「+ 出来事を追加」で出る欄も、重ならない id で label とつなぐ (Issue #189)
  it("links each day entry field to its label", () => {
    const labels = elements(root, "label").map((e) => directive(e, "bind", "for"))
    const fields = [...elements(root, "input"), ...elements(root, "textarea")]
    for (const key of ["title", "happened_on", "body"]) {
      const field = fields.find((e) => directive(e, "model") === `dayEntries[d._idx].${key}`)
      const id = directive(field, "bind", "id")
      expect(id, key).toContain("d._idx")
      expect(labels, key).toContain(id)
    }
  })

  it("links each select to its label", () => {
    const labels = elements(root, "label").map((e) => attr(e, "for"))
    expect(attr(category, "id")).toBe("trip-category")
    expect(attr(visibility, "id")).toBe("trip-visibility")
    expect(labels).toContain("trip-category")
    expect(labels).toContain("trip-visibility")
  })

  it("points every label to a field", () => {
    for (const label of elements(root, "label")) {
      expect(attr(label, "for") || directive(label, "bind", "for")).toBeTruthy()
    }
  })

  it("stacks category and visibility on narrow screens", () => {
    const grid = parentOf(root, parentOf(root, category))
    expect(attr(grid, "class")).toContain("grid-cols-1 sm:grid-cols-2")
  })

  it("hides the visibility select from guests", () => {
    expect(directive(parentOf(root, visibility), "if")).toBe("!auth.user?.guest")
  })

  it("stacks the save buttons on narrow screens", () => {
    const publish = elements(root, "button").find((e) => directive(e, "on", "click")?.includes("published"))
    const row = parentOf(root, publish)
    expect(attr(row, "class")).toContain("flex-col-reverse")
    expect(attr(row, "class")).toContain("sm:flex-row")
  })
})
