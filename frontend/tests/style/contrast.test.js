import { describe, it, expect } from "vitest"
import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"

// 文字と背景の比が WCAG AA の 4.5:1 に足りない色の組み合わせが、画面に残っていないことを確かめる (Issue #173)。
// app の全部の .vue を行ごとに読むので、新しい画面で同じ組み合わせを使っても見つかる。
// パスは frontend からの相対 (テストの環境 happy-dom では import.meta.url が file: にならない)。
const lines = readdirSync("app", { recursive: true })
  .filter((file) => file.endsWith(".vue"))
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

  it("does not use slate-500 text on a dark background (3.07:1)", () => {
    // 画像が無いときの 📷 の枠 (文字ではない飾り) だけは slate-500 のまま
    const uses = lines.filter((line) => /dark:text-slate-500/.test(line.text) && !/text-slate-300 dark:text-slate-500/.test(line.text))
    expect(uses.map((line) => line.at)).toEqual([])
  })
})
