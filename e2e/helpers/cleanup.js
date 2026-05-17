// Playwright globalTeardown: テスト群終了時に e2e_* prefix のテストデータを完全削除。
//
// 削除戦略 (Issue #72 で改修):
//   - 旧実装: `docker exec mysql DELETE FROM users WHERE email LIKE 'e2e\_%'`
//     → FOREIGN_KEY_CHECKS=0 で users のみ削除し、trip / comment / like / 各 trip 子
//        テーブルが orphan として残留する問題があった。
//   - 新実装: host の `bin/rails runner script/cleanup_test_users.rb` を呼び、
//     User.destroy_all 経由で `dependent: :destroy` 連鎖を全て効かせる。
//     comments / likes / favorites / memos / planned_spots / packing_items /
//     tickets / reviews / budgets / receipts / day_entries / trip_tags /
//     notifications / follows まで完全に連鎖削除される (orphan 0 保証)。
//
// 前提:
//   - host の backend/ 配下に bin/rails が存在する
//   - .env が source 済 (DB_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD)
//   - Rails 起動コストは 10-30 秒。E2E 全体の teardown 1 回のみなので許容。
//
// 失敗しても warn のみで続行 (CI を止めない)。

import { execSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const BACKEND_DIR = path.resolve(__dirname, "../../backend")

// LIKE pattern の `_` は wildcard なので literal underscore は `\_` でエスケープ必須。
const CLEANUP_PATTERN = process.env.E2E_CLEANUP_PATTERN || "e2e\\_%"

export default async function globalTeardown() {
  console.log(`\n[e2e teardown] cleaning ${CLEANUP_PATTERN} via bin/rails runner...`)
  try {
    execSync("bin/rails runner script/cleanup_test_users.rb", {
      cwd: BACKEND_DIR,
      env: { ...process.env, CLEANUP_PATTERN },
      stdio: "inherit"
    })
  } catch (err) {
    console.warn(`[e2e teardown] cleanup failure (continuing): ${err.message}`)
  }
}
