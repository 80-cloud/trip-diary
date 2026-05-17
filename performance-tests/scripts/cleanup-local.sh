#!/usr/bin/env bash
# ローカル MySQL のテストデータ (perf_* prefix) を完全削除する (Issue #72 で改修)。
#
# 削除戦略:
#   - 旧実装: `docker exec mysql DELETE FROM users WHERE email LIKE 'perf_%'`
#     + `DELETE FROM trips ...` で users と trips のみ削除 → trip 子 12 テーブル
#     (comments / likes / favorites / memos / planned_spots / packing_items /
#      tickets / reviews / budgets / receipts / day_entries / trip_tags) が orphan
#     として残留する問題があった。
#   - 新実装: host の `bin/rails runner script/cleanup_test_users.rb` 経由で
#     `User.destroy_all` 連鎖削除を行い、orphan を完全に防ぐ。
#
# 接頭辞は PERF_PREFIX env で指定 (既定 perf)。
# RUN_ID 指定時は当該 run のみ、未指定なら接頭辞全件を対象。
#
# 使い方:
#   bash performance-tests/scripts/cleanup-local.sh                                   # 全 perf_*
#   K6_RUN_ID=20260517_120000_a3f9d2 bash .../cleanup-local.sh                        # 当該 run のみ
#
# 前提: host で bin/rails が動作可能、.env を source 済 (DB_HOST / MYSQL_USER 等)。

set -euo pipefail

PERF_PREFIX="${PERF_PREFIX:-perf}"
RUN_ID="${K6_RUN_ID:-}"

# project root (このスクリプトは performance-tests/scripts/ にある)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/../../backend"

if [[ ! -x "${BACKEND_DIR}/bin/rails" ]]; then
  echo "ERROR: ${BACKEND_DIR}/bin/rails が見つかりません。プロジェクトルートから実行してください。" >&2
  exit 1
fi

# RUN_ID 指定時は email 末尾 6 桁で範囲を絞る。
# SQL LIKE で `_` は単一文字 wildcard のため literal `_` は `\_` でエスケープ必須。
if [[ -n "${RUN_ID}" ]]; then
  SHORT_ID="${RUN_ID: -6}"
  CLEANUP_PATTERN="${PERF_PREFIX}\\_${SHORT_ID}\\_%"
  echo "→ Cleanup target: PREFIX=${PERF_PREFIX} RUN_ID=${RUN_ID} (pattern: ${CLEANUP_PATTERN})"
else
  CLEANUP_PATTERN="${PERF_PREFIX}\\_%"
  echo "→ Cleanup target: ALL ${PERF_PREFIX}_* users (pattern: ${CLEANUP_PATTERN})"
fi

# Rails runner 経由で destroy_all (dependent: :destroy 連鎖)。
# Rails boot に 10-30 秒かかるが、perf scenarios 前後の 1-2 回のみなので許容。
export CLEANUP_PATTERN
cd "${BACKEND_DIR}"
bin/rails runner script/cleanup_test_users.rb
