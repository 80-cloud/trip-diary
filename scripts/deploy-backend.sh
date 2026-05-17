#!/usr/bin/env bash
# trip-diary backend (Rails) を ECR push + ECS Fargate rolling update する。
# 姉妹 PJ sns-board の scripts/deploy-backend.sh を Rails 用に適応。
#
# 処理フロー:
#   (1) 依存チェック (docker / aws / terraform / git) + AWS 認証確認
#   (2) git commit SHA から image tag を決定 (latest 禁止)
#   (3) terraform output から ECR URL / ECS cluster / ECS service を取得
#   (4) ECR login (aws ecr get-login-password)
#   (5) docker buildx build --platform linux/amd64 --tag <ecr>:<sha> --push backend/
#       (Apple Silicon Mac の arm64 image 誤 push を強制 amd64 で防止)
#   (6) --skip-tf-apply なら ここで終了
#   (7) terraform apply -var="backend_image_tag=<sha>" で Task Definition 更新
#   (8) aws ecs update-service --force-new-deployment で新 task 起動を保証
#   (9) aws ecs wait services-stable で rollout 完了を待つ
#
# 引数:
#   --dry-run         実 docker push / aws / terraform を叩かずコマンドを表示するのみ
#   --skip-tf-apply   image push のみで terraform apply / update-service を skip
#   --yes | -y        terraform apply に -auto-approve を渡す (CI 用、対話 skip)
#   -h | --help       本ヘッダーコメントを表示

set -euo pipefail

# ===== 引数解析 =====
DRY_RUN=false
SKIP_TF_APPLY=false
AUTO_APPROVE=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)       DRY_RUN=true ;;
    --skip-tf-apply) SKIP_TF_APPLY=true ;;
    --yes|-y)        AUTO_APPROVE=true ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg" >&2
      echo "Usage: $0 [--dry-run] [--skip-tf-apply] [--yes|-y]" >&2
      exit 1
      ;;
  esac
done

log() { printf '\033[1;34m[deploy-backend]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[deploy-backend ERROR]\033[0m %s\n' "$*" >&2; }

# run <cmd> [<args>...]: 引数 array をそのまま実行 (eval 不使用、shell injection 回避)。
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
for cmd in docker aws terraform git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "$cmd が PATH にありません"
    exit 1
  fi
done

if ! docker buildx version >/dev/null 2>&1; then
  err "docker buildx が利用不可。Docker Desktop or BuildKit を有効化してください"
  exit 1
fi

if [[ "$DRY_RUN" == "false" ]]; then
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    err "AWS 認証が未設定。aws configure / 環境変数で credentials を設定してください"
    exit 1
  fi
fi

# ===== (2) image tag = git commit SHA (短縮 7 文字) =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra"
BACKEND_DIR="$REPO_ROOT/backend"

if [[ ! -f "$BACKEND_DIR/Dockerfile" ]]; then
  err "$BACKEND_DIR/Dockerfile が存在しません"
  exit 1
fi

# uncommit / untracked 変更があると「git SHA != 実 image 内容」のねじれが起きるため警告。
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- backend/ 2>/dev/null)" ]]; then
  err "WARNING: backend/ に uncommitted / untracked な変更があります。image tag (git SHA) と実コードが不一致になります"
  err "         git status -- backend/ で確認、commit してから再実行を推奨"
fi

GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD)"
if [[ -z "$GIT_SHA" ]]; then
  err "git rev-parse 失敗。リポジトリ内で実行してください"
  exit 1
fi
log "(2) image tag = $GIT_SHA (git commit SHA 短縮 7 文字、latest tag は禁止)"

# ===== (3) terraform output から ECR URL / ECS cluster/service を取得 =====
log "(3) terraform output からデプロイ先を取得"

ECR_URL="$(terraform -chdir="$INFRA_DIR" output -raw ecr_repository_url 2>/dev/null || echo "")"
ECS_CLUSTER="$(terraform -chdir="$INFRA_DIR" output -raw ecs_cluster_name 2>/dev/null || echo "")"
ECS_SERVICE="$(terraform -chdir="$INFRA_DIR" output -raw ecs_service_name 2>/dev/null || echo "")"

if [[ -z "$ECR_URL" || -z "$ECS_CLUSTER" || -z "$ECS_SERVICE" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    log "  (dry-run: terraform output 空のため placeholder を使用)"
    ECR_URL="${ECR_URL:-DRYRUN.dkr.ecr.ap-northeast-1.amazonaws.com/trip-diary-backend}"
    ECS_CLUSTER="${ECS_CLUSTER:-trip-diary-cluster}"
    ECS_SERVICE="${ECS_SERVICE:-trip-diary-backend}"
  else
    err "terraform output が空です (terraform apply 済みであることを確認してください)"
    err "  ECR_URL=$ECR_URL ECS_CLUSTER=$ECS_CLUSTER ECS_SERVICE=$ECS_SERVICE"
    exit 1
  fi
fi

ECR_REGISTRY="${ECR_URL%%/*}"
AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo 'ap-northeast-1')}"
IMAGE_FULL="$ECR_URL:$GIT_SHA"

log "  ECR_URL     = $ECR_URL"
log "  ECS_CLUSTER = $ECS_CLUSTER"
log "  ECS_SERVICE = $ECS_SERVICE"
log "  IMAGE       = $IMAGE_FULL"

# ===== (4) ECR login =====
log "(4) ECR login"
if [[ "$DRY_RUN" == "false" ]]; then
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"
else
  echo "[DRY-RUN] aws ecr get-login-password ... | docker login ... $ECR_REGISTRY"
fi

# ===== (5) docker buildx build (amd64) + push =====
log "(5) docker buildx build --platform linux/amd64 + push (Apple Silicon arm64 誤 push 防止)"
run docker buildx build \
  --platform linux/amd64 \
  --tag "$IMAGE_FULL" \
  --push \
  "$BACKEND_DIR"

# ===== (6) --skip-tf-apply で早期終了 =====
if [[ "$SKIP_TF_APPLY" == "true" ]]; then
  log "(6) --skip-tf-apply 指定のため terraform apply / update-service は skip"
  log "完了 (image push のみ実施)"
  exit 0
fi

# ===== (7) terraform apply で Task Definition 更新 =====
log "(7) terraform apply -var=\"backend_image_tag=$GIT_SHA\""
TF_ARGS=(-chdir="$INFRA_DIR" apply -var="backend_image_tag=$GIT_SHA")
if [[ "$AUTO_APPROVE" == "true" ]]; then
  TF_ARGS+=(-auto-approve)
fi
run terraform "${TF_ARGS[@]}"

# ===== (8) ECS Service 強制再デプロイ =====
log "(8) aws ecs update-service --force-new-deployment"
run aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment \
  --region "$AWS_REGION" \
  >/dev/null

# ===== (9) rollout 完了待ち =====
log "(9) aws ecs wait services-stable (~3-5min 想定)"
run aws ecs wait services-stable \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION"

log "✅ backend デプロイ完了: $IMAGE_FULL"
