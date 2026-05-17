#!/usr/bin/env bash
# trip-diary 本番 AWS リソースの安全な取り壊し (Issue #59)。
# 姉妹 PJ sns-board の scripts/teardown.sh を Rails + trip-diary 用に適応。
#
# 処理フロー:
#   (1) 依存チェック (aws / terraform) + AWS 認証 + region 確認
#   (2) terraform state 上のリソース概要を表示
#   (3) 撤収後も残るリソースを明示警告 (tfstate bucket / Budgets / Subscription メール 等)
#   (4) ユーザーに 2 段階確認を求める (プロジェクト名 type-in + 最終 yes/no)
#   (5) terraform の撤収コマンドを実行 (force_destroy_resources=true で S3/ECR を中身ごと撤収)
#   (6) 撤収後の検証: aws ecs / aws rds / aws elbv2 / cloudfront で残存ゼロ判定
#
# 引数:
#   --dry-run        実撤収せず terraform plan -destroy のみ表示
#   --skip-confirm   2 段階確認を skip (CI / 自動化用、対話なし)。本番では使わない
#
# 注意:
#   - Claude Code / 修練城ハードウォールから直接実行不可 (terraform destroy をブロック)。
#     **ユーザーが手動でターミナルから実行する想定**。
#   - tfstate bucket "trip-diary-tfstate" 自体は対象外 (手動削除)。
#     再 apply 時に同じ tfstate を使いたい場合は残置推奨。

set -euo pipefail

# ===== 引数解析 =====
DRY_RUN=0
SKIP_CONFIRM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)      DRY_RUN=1 ;;
    --skip-confirm) SKIP_CONFIRM=1 ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# ===== 色 (TTY のみ) =====
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_GRN=$'\033[32m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_YEL=""; C_GRN=""; C_OFF=""
fi

log()  { printf "%s\n" "$*"; }
warn() { printf "%s%s%s\n" "$C_YEL" "$*" "$C_OFF" >&2; }
err()  { printf "%s%s%s\n" "$C_RED" "$*" "$C_OFF" >&2; }
ok()   { printf "%s%s%s\n" "$C_GRN" "$*" "$C_OFF"; }

# ===== (1) 依存 + 認証チェック =====
log "==> (1) 依存・認証チェック"
for cmd in aws terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "$cmd が見つかりません。インストールしてください。"
    exit 1
  fi
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
INFRA_DIR="$REPO_ROOT/infra"
if [ ! -d "$INFRA_DIR" ]; then
  err "$INFRA_DIR が存在しません。リポジトリルートから実行してください。"
  exit 1
fi

# AWS 認証 + region
if ! AWS_IDENTITY=$(aws sts get-caller-identity --output json 2>&1); then
  err "AWS 認証失敗: $AWS_IDENTITY"
  err "AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY または aws configure を確認してください。"
  exit 1
fi
ACCOUNT_ID=$(printf "%s" "$AWS_IDENTITY" | sed -n 's/.*"Account": "\([0-9]*\)".*/\1/p')
AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || printf 'ap-northeast-1')}"
log "  AWS Account: $ACCOUNT_ID"
log "  AWS Region:  $AWS_REGION"

# ===== (2) terraform state 概要 =====
log ""
log "==> (2) terraform state 上のリソース概要"
cd "$INFRA_DIR"

if ! terraform state list >/dev/null 2>&1; then
  warn "terraform state が空です (init 未済 or 既に撤収済)。"
  warn "init を実行する場合: terraform -chdir=$INFRA_DIR init"
  exit 0
fi

RESOURCE_COUNT=$(terraform state list | wc -l | tr -d ' ')
log "  state 上のリソース数: $RESOURCE_COUNT"
terraform state list | head -20 | sed 's/^/    /'
if [ "$RESOURCE_COUNT" -gt 20 ]; then
  log "    ... (他 $((RESOURCE_COUNT - 20)) 件)"
fi

# ===== (3) 残存リソース警告 =====
log ""
warn "==> (3) 撤収後も残るリソース (要手動確認)"
warn "  - tfstate bucket (S3 trip-diary-tfstate): backend 用、本 script 対象外"
warn "  - AWS Budgets: 月次通知メール宛先が残る (削除したい場合は AWS console で別途)"
warn "  - SNS Subscription (Budget 通知用): 残る場合あり (AWS console で確認)"
warn "  - CloudWatch log groups: retention 7 日で自然消滅"
warn "  - ECR repository: var.force_destroy_resources=true で撤収 (image 含む)"
warn "  - S3 buckets (uploads/frontend): 同上、中身ごと撤収"

# ===== (4) 2 段階確認 =====
log ""
log "==> (4) 2 段階確認"

if [ "$SKIP_CONFIRM" -eq 1 ]; then
  warn "  --skip-confirm 指定により対話 skip"
elif [ "$DRY_RUN" -eq 1 ]; then
  log "  --dry-run 指定のため対話 skip (plan のみ実行)"
else
  printf "  確認 1/2: 撤収対象は AWS Account %s / Region %s です。\n" "$ACCOUNT_ID" "$AWS_REGION"
  printf "          続行するには 'trip-diary' と入力してください: "
  read -r confirm1
  if [ "$confirm1" != "trip-diary" ]; then
    err "入力が一致しません。中止しました。"
    exit 1
  fi

  printf "  確認 2/2: 全 %s 件のリソースを撤収します。本当に実行しますか? [yes/NO]: " "$RESOURCE_COUNT"
  read -r confirm2
  if [ "$confirm2" != "yes" ]; then
    err "yes 以外が入力されました。中止しました。"
    exit 1
  fi
fi

# ===== (5) 撤収 =====
log ""
log "==> (5) terraform $([ $DRY_RUN -eq 1 ] && printf 'plan -destroy' || printf 'destroy')"

# force_destroy_resources=true で S3/ECR を中身ごと撤収可能にする
TF_ARGS=("-var=force_destroy_resources=true")

if [ "$DRY_RUN" -eq 1 ]; then
  terraform plan -destroy "${TF_ARGS[@]}"
  ok "dry-run 完了。実撤収する場合は --dry-run なしで再実行してください。"
  exit 0
fi

if ! terraform destroy -auto-approve "${TF_ARGS[@]}"; then
  err "terraform destroy 失敗。残存リソースを手動確認してください。"
  err "  - aws ecs list-services --cluster trip-diary-cluster"
  err "  - aws elbv2 describe-load-balancers"
  err "  - aws rds describe-db-instances"
  err "  - aws cloudfront list-distributions"
  exit 1
fi

# ===== (6) 残存検証 =====
log ""
log "==> (6) 撤収後検証"

REMAIN_ECS=$(aws ecs list-services --cluster trip-diary-cluster --query 'serviceArns | length(@)' --output text 2>/dev/null || printf 0)
REMAIN_ALB=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, 'trip-diary')] | length(@)" --output text 2>/dev/null || printf 0)
REMAIN_RDS=$(aws rds describe-db-instances --query "DBInstances[?starts_with(DBInstanceIdentifier, 'trip-diary')] | length(@)" --output text 2>/dev/null || printf 0)
REMAIN_CF=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, 'trip-diary')] | length(@)" --output text 2>/dev/null || printf 0)

log "  ECS services: $REMAIN_ECS / ALB: $REMAIN_ALB / RDS: $REMAIN_RDS / CloudFront: $REMAIN_CF"

if [ "$REMAIN_ECS" = "0" ] && [ "$REMAIN_ALB" = "0" ] && [ "$REMAIN_RDS" = "0" ] && [ "$REMAIN_CF" = "0" ]; then
  ok ""
  ok "撤収完了。課金リソースの主要分はゼロです。"
  ok "AWS Budgets ダッシュボードで実 cost を翌日確認してください (\$30 上限通知メール宛先は残ります)。"
else
  warn ""
  warn "撤収完了したが上記のリソースが残存しています。AWS console で手動確認してください。"
  exit 1
fi
