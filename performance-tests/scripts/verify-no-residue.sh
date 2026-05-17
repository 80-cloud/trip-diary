#!/usr/bin/env bash
# 残骸検知。PERF_PREFIX (既定 perf) のユーザ件数を返す。1 件以上残っていれば exit 1。
# CI と手動どちらでも安全確認に使う。

set -euo pipefail

PERF_PREFIX="${PERF_PREFIX:-perf}"
PERF_DB_CONTAINER="${PERF_DB_CONTAINER:-trip-diary-mysql}"
PERF_DB_NAME="${PERF_DB_NAME:-${MYSQL_DATABASE:-trip_diary_dev}}"
PERF_DB_USER="${PERF_DB_USER:-root}"
PERF_DB_PASSWORD="${PERF_DB_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}"

if [[ -z "${PERF_DB_PASSWORD}" ]]; then
  echo "ERROR: PERF_DB_PASSWORD (or MYSQL_ROOT_PASSWORD) が未設定。.env を source してください。" >&2
  exit 127
fi

count=$(docker exec "${PERF_DB_CONTAINER}" mysql \
  -u"${PERF_DB_USER}" -p"${PERF_DB_PASSWORD}" \
  -N -B -e "SELECT COUNT(*) FROM users WHERE email LIKE '${PERF_PREFIX}\\_%'" \
  "${PERF_DB_NAME}" 2>&1 | (grep -v "Using a password" || true) | tr -d '[:space:]')

echo "${PERF_PREFIX}_* user count: ${count}"

if [[ "${count}" -gt 0 ]]; then
  echo "✗ 残骸あり。cleanup-local.sh を実行してください。" >&2
  exit 1
fi
echo "✓ 残骸なし"
