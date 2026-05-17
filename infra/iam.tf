# ECS Fargate 用 IAM ロール。
# docs/インフラ構成.md §2-4 (最小権限) / 修練城教訓「最小権限スコープ」。
#
# 設計判断:
# - 2 ロール分離: ECS では task_execution_role (起動時) と task_role (実行時) を分離する
#   AWS ベストプラクティス。漏洩時の影響範囲を最小化
#   - task_execution_role: ECS が task 起動時に使用 (ECR pull / awslogs / SSM secrets 解決)
#   - task_role: container 内のアプリが使用 (S3 アップロード)
# - SSM 参照 scope は /${project}/prod/* に限定
# - KMS Decrypt は kms:ViaService 条件で SSM 経由のみに限定 (横断的鍵漏洩防止)

data "aws_caller_identity" "current" {}

# ===== ECS Task Execution Role =====

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project}-ecs-task-execution"
  }
}

# CloudWatch Logs (awslogs ドライバーが container ログを送る)。
# tfsec:ignore:AVD-AWS-0057
resource "aws_iam_role_policy" "ecs_task_execution_logs" {
  name = "${var.project}-ecs-execution-logs"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.project}/*"
    }]
  })
}

# ECR pull (image 取得)。
# GetAuthorizationToken は Resource="*" 必須 (AWS 仕様)。
resource "aws_iam_role_policy" "ecs_task_execution_ecr" {
  name = "${var.project}-ecs-execution-ecr"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.backend.arn
      }
    ]
  })
}

# SSM Parameter Store からの secrets 解決 (Task Definition secrets[].valueFrom 経由)。
# AWS managed SSM キー (alias/aws/ssm) 経由に kms:ViaService で限定し最小権限化。
resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name = "${var.project}-ecs-execution-ssm"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECS は内部で GetParameters (複数同時取得) のみを使う。GetParameter (単数) は不要 (最小権限)。
        Effect   = "Allow"
        Action   = "ssm:GetParameters"
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/prod/*"
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ===== ECS Task Role =====
# container 内のアプリが使用 (Active Storage の S3 アップロード)。

resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project}-ecs-task"
  }
}

# S3 uploads バケットへの Active Storage 操作。
# Active Storage は PutObject / GetObject / DeleteObject を使う。
# Resource はバケット配下オブジェクトに限定 (バケット自体の操作権限は与えない)。
# tfsec:ignore:AVD-AWS-0057
resource "aws_iam_role_policy" "ecs_task_s3_uploads" {
  name = "${var.project}-ecs-task-s3-uploads"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.uploads.arn}/*"
      },
      # Active Storage の direct upload で HEAD / metadata 取得が必要な場合がある
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.uploads.arn
      }
    ]
  })
}
