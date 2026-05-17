#!/usr/bin/env bash
# trip-diary frontend (Nuxt SPA) を CloudFront + S3 にデプロイする。
# 姉妹 PJ sns-board の scripts/deploy-frontend.sh を Nuxt 用に適応。
#
# 処理フロー:
#   (1) 依存チェック (aws / npm / terraform) + AWS 認証確認
#   (2) terraform output から frontend bucket name / CloudFront distribution ID を取得
#       (環境変数 FRONTEND_BUCKET / CLOUDFRONT_DISTRIBUTION_ID で上書き可)
#   (3) frontend を **npm run generate** で SSG ビルド (.output/public/ に静的 HTML 出力)
#       npm run build は Nitro server を含む node-server 構成で index.html を出さない
#       (S3 静的配信不可)。ssr:false + generate で SPA + プリレンダ済 index.html を得る
#   (4) .output/public/_nuxt/ を S3 sync (Cache-Control: max-age=31536000, immutable)
#   (5) .output/public/index.html を S3 cp (Cache-Control: no-cache, must-revalidate)
#   (6) .output/public/ のその他ファイル (favicon.ico / 200.html / 404.html / 各 route 用
#       index.html 等) を S3 sync (Cache-Control: no-cache)
#   (7) CloudFront に /index.html / / だけ invalidation (assets は immutable cache のため不要)
#
# 引数:
#   --dry-run    実 AWS API を叩かずコマンドを表示するのみ

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

log() { printf '\033[1;34m[deploy-frontend]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[deploy-frontend ERROR]\033[0m %s\n' "$*" >&2; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '\033[1;33m[DRY-RUN]\033[0m'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# ===== (1) 依存 + 認証チェック =====
log "(1) 依存コマンドを確認"
for cmd in aws npm terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "$cmd が PATH にありません"
    exit 1
  fi
done

if [[ "$DRY_RUN" == "false" ]]; then
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    err "AWS 認証が未設定"
    exit 1
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra"
FRONTEND_DIR="$REPO_ROOT/frontend"

# ===== (2) terraform output から bucket / distribution ID 取得 =====
log "(2) terraform output から frontend bucket / CloudFront distribution を取得"
FRONTEND_BUCKET="${FRONTEND_BUCKET:-$(terraform -chdir="$INFRA_DIR" output -raw frontend_bucket_name 2>/dev/null || echo "")}"
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-$(terraform -chdir="$INFRA_DIR" output -raw cloudfront_distribution_id 2>/dev/null || echo "")}"
CF_DOMAIN="$(terraform -chdir="$INFRA_DIR" output -raw cloudfront_domain_name 2>/dev/null || echo "")"

if [[ -z "$FRONTEND_BUCKET" || -z "$CLOUDFRONT_DISTRIBUTION_ID" ]]; then
  err "terraform output が空です (terraform apply 済みか、env で FRONTEND_BUCKET / CLOUDFRONT_DISTRIBUTION_ID 指定)"
  exit 1
fi
log "  FRONTEND_BUCKET            = $FRONTEND_BUCKET"
log "  CLOUDFRONT_DISTRIBUTION_ID = $CLOUDFRONT_DISTRIBUTION_ID"
log "  CF_DOMAIN                  = ${CF_DOMAIN:-(unknown)}"

# ===== (3) Nuxt SSG build =====
log "(3) Nuxt SSG build (npm run generate / ssr:false + プリレンダ済 index.html を出力)"
# NUXT_PUBLIC_API_BASE を CloudFront 経由の /api/v1 に設定して同一オリジン化
if [[ -n "$CF_DOMAIN" ]]; then
  export NUXT_PUBLIC_API_BASE="https://${CF_DOMAIN}/api/v1"
  log "  NUXT_PUBLIC_API_BASE = $NUXT_PUBLIC_API_BASE"
fi
# npm run build (node-server 構成) は index.html を出さず S3 配信不可。
# npm run generate (SSG) で .output/public/ にプリレンダ済 HTML + _nuxt/* assets を生成。
run bash -c "cd '$FRONTEND_DIR' && npm run generate"

NUXT_DIST="$FRONTEND_DIR/.output/public"
if [[ ! -d "$NUXT_DIST" ]]; then
  err "$NUXT_DIST が存在しません (npm run generate 失敗?)"
  exit 1
fi
if [[ ! -f "$NUXT_DIST/index.html" ]]; then
  err "$NUXT_DIST/index.html がありません (Nuxt が SPA HTML をプリレンダしていない / nuxt.config.ts の ssr 設定を確認)"
  exit 1
fi

# ===== (4) _nuxt/ assets を S3 sync (immutable cache) =====
log "(4) _nuxt/* を S3 sync (immutable cache: 1 year)"
if [[ -d "$NUXT_DIST/_nuxt" ]]; then
  run aws s3 sync "$NUXT_DIST/_nuxt/" "s3://$FRONTEND_BUCKET/_nuxt/" \
    --delete \
    --cache-control "public,max-age=31536000,immutable"
fi

# ===== (5) index.html を S3 cp (no-cache) =====
log "(5) index.html を S3 cp (no-cache, must-revalidate)"
run aws s3 cp "$NUXT_DIST/index.html" "s3://$FRONTEND_BUCKET/index.html" \
  --cache-control "no-cache,must-revalidate" \
  --content-type "text/html; charset=utf-8"

# ===== (6) その他ファイル (favicon 等) を S3 sync (no-cache) =====
log "(6) その他ファイル (favicon 等) を S3 sync (no-cache)"
run aws s3 sync "$NUXT_DIST/" "s3://$FRONTEND_BUCKET/" \
  --exclude "_nuxt/*" \
  --exclude "index.html" \
  --cache-control "no-cache"

# ===== (7) CloudFront invalidation =====
log "(7) CloudFront invalidation / + /index.html + /200.html + /404.html (assets は immutable のため不要)"
run aws cloudfront create-invalidation \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/" "/index.html" "/200.html" "/404.html" \
  >/dev/null

log "✅ frontend デプロイ完了: https://${CF_DOMAIN}/"
