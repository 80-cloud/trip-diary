import { describe, it, expect } from "vitest"
import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { parse } from "vue/compiler-sfc"

// 文字と背景の比が WCAG AA の 4.5:1 に足りない色の組み合わせが、画面に残っていないことを確かめる (Issue #173)。
// app の全部の .vue を行ごとに読むので、新しい画面で同じ組み合わせを使っても見つかる。
// パスは frontend からの相対 (テストの環境 happy-dom では import.meta.url が file: にならない)。
const files = readdirSync("app", { recursive: true }).filter((file) => file.endsWith(".vue"))
const lines = files
  .flatMap((file) => readFileSync(join("app", file), "utf8").split("\n").map((text, i) => ({ at: `${file}:${i + 1}`, text })))

function found(pattern) {
  return lines.filter((line) => pattern.test(line.text)).map((line) => line.at)
}

describe("colors in app/**/*.vue", () => {
  it("does not put white text on brand-500 (4.10:1)", () => {
    // 文字の無い飾り (計画の進み具合の棒) だけは brand-500 のまま
    const uses = lines.filter((line) => /bg-brand-500/.test(line.text) && !/h-full bg-brand-500/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })

  it("does not use slate-400 text on a light background (2.56:1)", () => {
    expect(found(/(^|[\s"`[])text-slate-400/)).toEqual([])
  })

  it("gives slate-500 text a lighter color in dark mode (3.07:1)", () => {
    const uses = lines.filter((line) => /(^|[ "`[])text-slate-500( |"|$)/.test(line.text) && !/dark:text-slate-400/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })

  it("does not use slate-500 text on a dark background (3.07:1)", () => {
    // 画像が無いときの 📷 の枠 (文字ではない飾り) だけは slate-500 のまま
    const uses = lines.filter((line) => /dark:text-slate-500/.test(line.text) && !/text-slate-300 dark:text-slate-500/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })

  // 赤系の文字とボタン (Issue #200)。文字の無い飾り (予算の棒・カテゴリの印) の bg-rose は対象外
  it("does not use rose-500 text (3.67:1 / 3.98:1)", () => {
    expect(found(/text-rose-500/)).toEqual([])
  })

  it("does not put white text on rose-500 (3.67:1)", () => {
    const uses = lines.filter((line) => /bg-rose-500/.test(line.text) && /text-white/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })

  it("gives rose-600 text a lighter color in dark mode (3.11:1)", () => {
    const uses = lines.filter((line) => /text-rose-600/.test(line.text) && !/dark:text-rose-/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })

  it("does not use rose-600 text on rose-50 (4.28:1)", () => {
    const uses = lines.filter((line) => /bg-rose-50 /.test(line.text) && /text-rose-600/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })

  // ダークで打った文字が見えなくならないよう、入力欄には背景と文字の色をダーク用にも付ける (Issue #200)
  it("gives every text field colors for dark mode", () => {
    const fields = (node) => (node.type === 1 && ["input", "textarea", "select"].includes(node.tag) ? [node] : [])
      .concat((node.children || []).flatMap(fields))
    const missing = files.flatMap((file) => {
      const template = parse(readFileSync(join("app", file), "utf8")).descriptor.template
      return template ? fields(template.ast).map((field) => ({ field, at: `${file}:${field.loc.start.line}` })) : []
    }).filter(({ field }) => {
      const attr = (name) => field.props.find((p) => p.type === 6 && p.name === name)?.value?.content || ""
      if (["checkbox", "file", "hidden", "radio"].includes(attr("type"))) return false
      return !/dark:bg-/.test(attr("class")) || !/dark:text-/.test(attr("class"))
    })
    expect(missing.map(({ at }) => at)).toEqual([])
  })
})
