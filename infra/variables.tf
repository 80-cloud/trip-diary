# Phase 3 (VPC + Subnet + SG + ECS Fargate + RDS + S3 + ECR + CloudFront + Budgets) の変数定義。
# 値は terraform.tfvars で指定する (terraform.tfvars は Git 管理しない、.gitignore 参照)。
#
# 姉妹 PJ sns-board の infra/variables.tf を Rails + MySQL 向けに適応。

variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "リソース命名・タグのプレフィックス"
  type        = string
  default     = "trip-diary"
}

# ===== ネットワーク =====

variable "vpc_cidr" {
  description = "VPC の CIDR ブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "パブリックサブネット A (ECS Fargate task + ALB の 1 AZ 目) の CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_c_cidr" {
  description = "パブリックサブネット C (DB Subnet Group の 2 AZ 目 + ALB の 2 AZ 目) の CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "az_a" {
  description = "アベイラビリティゾーン A (ECS task + RDS 配置)"
  type        = string
  default     = "ap-northeast-1a"
}

variable "az_c" {
  description = "アベイラビリティゾーン C (DB Subnet Group + ALB 2 AZ 目)"
  type        = string
  default     = "ap-northeast-1c"
}

# ===== ECS Fargate (ecs.tf) =====

variable "ecs_task_cpu" {
  description = "ECS Fargate task の CPU units (256 = 0.25 vCPU、Fargate 最小)。Rails + Thruster の起動には十分"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_task_cpu)
    error_message = "ecs_task_cpu は Fargate 規定値 (256/512/1024/2048/4096) のいずれかを指定してください"
  }
}

variable "ecs_task_memory" {
  description = "ECS Fargate task のメモリ (MiB)。Rails + bootsnap + jemalloc + image_processing で 512 では起動失敗のリスクあり。1024 を default に"
  type        = number
  default     = 1024

  validation {
    condition     = var.ecs_task_memory >= 512 && var.ecs_task_memory <= 30720
    error_message = "ecs_task_memory は 512 MiB 以上を指定してください"
  }
}

# ===== RDS =====

variable "rds_instance_class" {
  description = "RDS インスタンスクラス。無料枠は db.t3.micro"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "RDS の初期データベース名 (Rails primary database)"
  type        = string
  default     = "trip_diary_prod"
}

variable "db_username" {
  description = "RDS マスターユーザー名"
  type        = string
  default     = "trip"
}

variable "db_password" {
  description = "RDS マスターパスワード。terraform.tfvars で強力な値を指定する (Git 管理しない)"
  type        = string
  sensitive   = true
}

# ===== S3 =====

variable "s3_bucket_name" {
  description = "画像アップロード用 S3 バケット名。S3 はグローバル一意のため既存と衝突しない名前を指定する (例: trip-diary-uploads-prod-<account-id>)"
  type        = string
}

# ===== ALB =====

variable "acm_certificate_arn" {
  description = "ALB の HTTPS リスナーに使う ACM 証明書 ARN (ap-northeast-1 リージョン)。空なら HTTP リスナーのみ作成。証明書発行・ドメイン取得・Route 53 は別 PR スコープ"
  type        = string
  default     = ""
}

# ===== アプリ設定 (SSM Parameter Store 経由で ECS Task に注入、ssm.tf) =====

variable "rails_master_key" {
  description = "Rails credentials.yml.enc の復号鍵 (config/master.key の中身)。terraform.tfvars で指定 (Git 管理しない)。生成例: rails credentials:edit 実行時に自動生成"
  type        = string
  sensitive   = true
}

variable "secret_key_base" {
  description = "Rails の Cookie 暗号化用 SECRET_KEY_BASE。32 文字以上の強力なランダム値。生成例: bin/rails secret"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT 署名鍵 (HS256)。32 文字以上の強力なランダム値。生成例: openssl rand -base64 48"
  type        = string
  sensitive   = true
}

variable "cors_allowed_origins" {
  description = "CORS 許可オリジン (カンマ区切り)。空なら CloudFront 既定ドメインを https で使う。独自ドメイン採用時に明示指定"
  type        = string
  default     = ""
}

# ===== ECR (ecr.tf) / ECS Task Definition (ecs.tf) =====

variable "backend_image_tag" {
  description = "ECS Task Definition で参照する backend image tag。default 値なし required (latest 等の mutable tag を本番に誤投入する事故を防ぐ)。推奨: commit SHA の 7 文字 (例: a1b2c3d)"
  type        = string

  validation {
    condition     = length(var.backend_image_tag) > 0 && var.backend_image_tag != "latest"
    error_message = "backend_image_tag は空文字 / latest 不可 (本番安全側、再現性確保のため immutable tag を指定)"
  }
}

# ===== CloudFront (cloudfront.tf) =====

variable "cloudfront_price_class" {
  description = "CloudFront 配信料金クラス。PriceClass_100=北米+欧州 / PriceClass_200=+ 日本含むアジア / PriceClass_All=全エッジ。日本ユーザー想定で 200 推奨"
  type        = string
  default     = "PriceClass_200"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class は PriceClass_100 / PriceClass_200 / PriceClass_All のいずれかを指定してください"
  }
}

# ===== デモ / 学習用 tear-down 運用 =====

variable "force_destroy_resources" {
  description = "デモ apply→tear-down を繰り返す際に true。S3 (uploads/frontend) と ECR (backend) を中身ごと削除可能にする。本番運用では必ず false (default)、誤適用で全画像/全 image 喪失リスク"
  type        = bool
  default     = false
}

# ===== AWS Budgets (budgets.tf) =====

variable "budget_limit_usd" {
  description = "月次コスト上限 (USD)。Fargate ~$9 + ALB ~$18 + CloudFront/S3 ~$3 = 計画 $30。80% / 100% / 100% forecasted の 3 段で通知"
  type        = number
  default     = 30

  validation {
    condition     = var.budget_limit_usd > 0 && var.budget_limit_usd <= 1000
    error_message = "budget_limit_usd は 1 〜 1000 USD の範囲で指定してください (学習用途で 1000 USD 以上は誤設定の可能性)"
  }
}

variable "budget_notification_email" {
  description = "Budgets 通知の宛先メールアドレス。terraform.tfvars で必須指定 (本番安全側のため default 値なし)"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_notification_email))
    error_message = "budget_notification_email は有効なメール形式で指定してください"
  }
}
