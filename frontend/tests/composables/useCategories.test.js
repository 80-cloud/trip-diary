import { describe, it, expect } from "vitest"
import { useCategories, CATEGORY_OPTIONS } from "~/composables/useCategories.js"

describe("useCategories", () => {
  it("CATEGORY_OPTIONS は 8 種類", () => {
    expect(CATEGORY_OPTIONS).toHaveLength(8)
  })

  it("CATEGORY_OPTIONS の value は Rails enum と一致する", () => {
    const expectedValues = ["domestic", "overseas", "solo", "gourmet", "heritage", "family", "outdoor", "business"]
    expect(CATEGORY_OPTIONS.map((o) => o.value).sort()).toEqual(expectedValues.sort())
  })

  it("labelOf は既知の value を日本語ラベルに変換する", () => {
    const { labelOf } = useCategories()
    expect(labelOf("domestic")).toBe("国内")
    expect(labelOf("overseas")).toBe("海外")
    expect(labelOf("gourmet")).toBe("グルメ")
  })

  it("labelOf は未知の value をそのまま返す (フォールバック)", () => {
    const { labelOf } = useCategories()
    expect(labelOf("unknown_xyz")).toBe("unknown_xyz")
    expect(labelOf("")).toBe("")
  })
})
