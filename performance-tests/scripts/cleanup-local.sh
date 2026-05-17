#!/usr/bin/env bash
# ローカル MySQL のテストデータをまとめて削除する (sns-board scripts/cleanup-local.sh 踏襲)。
# users 削除で trips / comments / likes / favorites / planned_spots / ... も
# Rails dependent: :destroy 経由で消える想定 (本 PR では FK CASCADE off のため
# E2E と同じく FOREIGN_KEY_CHECKS=0 を一時的に切って users を削除する形式)。
#
# 接頭辞は PERF_PREFIX env で指定 (既定 perf)。
# RUN_ID 指定時は当該 run のみ、未指定なら接頭辞全件を対象。
#
# 使い方:
#   bash performance-tests/scripts/cleanup-local.sh                                   # 全 perf_*
#   K6_RUN_ID=20260517_120000_a3f9d2 bash .../cleanup-local.sh                        # 当該 run のみ

set -euo pipefail

PERF_PREFIX="${PERF_PREFIX:-perf}"
RUN_ID="${K6_RUN_ID:-}"

PERF_DB_CONTAINER="${PERF_DB_CONTAINER:-trip-diary-mysql}"
PERF_DB_NAME="${PERF_DB_NAME:-${MYSQL_DATABASE:-trip_diary_dev}}"
PERF_DB_USER="${PERF_DB_USER:-root}"
PERF_DB_PASSWORD="${PERF_DB_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}"

if [[ -z "${PERF_DB_PASSWORD}" ]]; then
  echo "ERROR: PERF_DB_PASSWORD (or MYSQL_ROOT_PASSWORD) が未設定。.env を source してください。" >&2
  exit 1
fi

# RUN_ID 指定時は email 末尾 6 桁で範囲を絞る。
# SQL LIKE で `_` は単一文字 wildcard のため literal `_` は `\_` でエスケープ必須。
if [[ -n "${RUN_ID}" ]]; then
  SHORT_ID="${RUN_ID: -6}"
  EMAIL_LIKE="${PERF_PREFIX}\\_${SHORT_ID}\\_%"
  echo "→ Cleanup target: PREFIX=${PERF_PREFIX} RUN_ID=${RUN_ID} (pattern: ${EMAIL_LIKE})"
else
  EMAIL_LIKE="${PERF_PREFIX}\\_%"
  echo "→ Cleanup target: ALL ${PERF_PREFIX}_* users (no RUN_ID specified)"
fi

mysql_exec() {
  # `grep -v` はマッチなしで exit 1 を返し set -euo pipefail で die するため、
  # subshell + `|| true` で握り潰す (MySQL 自体のエラーは stdout に乗らないので別途検知)。
  docker exec "${PERF_DB_CONTAINER}" mysql \
    -u"${PERF_DB_USER}" -p"${PERF_DB_PASSWORD}" \
    -N -B -e "$1" "${PERF_DB_NAME}" 2>&1 | (grep -v "Using a password" || true)
}

# 1) 削除前カウント
BEFORE=$(mysql_exec "SELECT COUNT(*) FROM users WHERE email LIKE '${EMAIL_LIKE}'" | tr -d '[:space:]')
echo "  users matching pattern: ${BEFORE}"

if [[ "${BEFORE}" -gt 0 ]]; then
  # 2) trips を先に削除してから users を削除
  #    sns-board は PostgreSQL ON DELETE CASCADE 設定済だが trip-diary は無設定 →
  #    users だけ削除すると trips が orphan として残り、後続 GET /api/v1/trips が
  #    500 (NoMethodError: undefined method 'id' for nil) になる。
  # 安全性: workers: 1 直列実行 / perf_* prefix 限定 / 別 spec との race なし
  #
  # 既知の制限: 本実装は trips + users のみ削除。trip-owned 子テーブル
  # (comments / likes / favorites / memos / planned_spots / packing_items /
  # tickets / reviews / budgets / receipts / day_entries / trip_tags) は
  # FOREIGN_KEY_CHECKS=0 によって orphan のまま残る可能性がある。
  # 後続の長期実行で蓄積した場合の対処:
  #   bin/rails runner "User.where('email LIKE ?', 'perf_%').destroy_all"
  # で dependent: :destroy 連鎖削除を全て効かせる (Rails 起動 10-30s)。
  # 本 PR では smoke が短時間で完結するため最小実装で許容、改善は別 Issue 化。
  mysql_exec "SET FOREIGN_KEY_CHECKS=0; \
    DELETE FROM trips WHERE user_id IN (SELECT id FROM users WHERE email LIKE '${EMAIL_LIKE}'); \
    DELETE FROM users WHERE email LIKE '${EMAIL_LIKE}'; \
    SET FOREIGN_KEY_CHECKS=1;"
fi

AFTER=$(mysql_exec "SELECT COUNT(*) FROM users WHERE email LIKE '${EMAIL_LIKE}'" | tr -d '[:space:]')
echo "  users after delete: ${AFTER}"

if [[ "${AFTER}" -gt 0 ]]; then
  echo "WARN: ${AFTER} users still remain — investigate manually." >&2
  exit 1
fi

echo "✓ cleanup-local.sh complete (prefix=${PERF_PREFIX}, deleted=${BEFORE})"
