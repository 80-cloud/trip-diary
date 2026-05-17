# ECR repository (backend Rails image)。Phase 3 で ECS Fargate が pull する。
#
# 設計判断:
# - image_tag_mutability = IMMUTABLE: tag 上書き禁止で監査追跡性を確保
# - scan_on_push = enabled: push 時に AWS の基本脆弱性スキャンを実行 (Free Tier)
# - encryption_type = AES256: KMS CMK は無料枠外
# - lifecycle policy: タグ付き 5 個 + 未タグ 1 日で削除

# tfsec:ignore:aws-ecr-repository-customer-key
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}-backend"
  image_tag_mutability = "IMMUTABLE"

  # デモ apply→tear-down 運用時に true、本番 default false。
  force_delete = var.force_destroy_resources

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "タグ付き image は直近 5 個まで保持 (ロールバック余地確保)"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "未タグ image は 1 日で削除 (build 中間物・ストレージコスト抑制)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
