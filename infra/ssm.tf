# アプリ設定 (.env 相当) を SSM Parameter Store で管理する。
# docs/インフラ構成.md §2-4 (機密管理) / 姉妹 PJ sns-board の infra/ssm.tf 踏襲。
#
# 設計方針:
#   - パラメータ階層は /${project}/prod/ 配下に集約。IAM はこの prefix で最小権限化 (iam.tf)。
#   - 機密 (DB パスワード / JWT secret / RAILS_MASTER_KEY / SECRET_KEY_BASE) は SecureString
#     (デフォルト KMS キー alias/aws/ssm で暗号化)。
#   - 非機密は String。
#   - ECS Fargate Task Definition の secrets[].valueFrom が起動時に解決 (ecs.tf)。
#     execution_role に ssm:GetParameters + kms:Decrypt 権限が必要 (iam.tf)。
#   - S3 アクセスは IAM ロール (iam.tf の ecs_task_s3_uploads) を使うため AWS_ACCESS_KEY_ID/
#     AWS_SECRET_ACCESS_KEY は SSM に置かない (静的キーを作らない)。Active Storage の
#     amazon サービスは AWS デフォルト認証チェーンで ECS task role を解決する。
#
# !!! 重要: SSM 値変更後の ECS Service 再起動 !!!
# SSM Parameter の値を変更しても ECS Service は自動再起動しないため、apply 後に明示再起動が必要:
#   aws ecs update-service --cluster trip-diary-cluster --service trip-diary-backend \
#     --force-new-deployment

locals {
  ssm_prefix = "/${var.project}/prod"

  # 非機密パラメータ。値は Terraform リソースから組み立てる (ハードコード回避)。
  # Rails 8 の database.yml が個別 ENV (DB_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD /
  # MYSQL_DATABASE) を読むため、それに合わせて key を設定する。
  ssm_string_params = {
    # Rails / Bundler
    RAILS_ENV                = "production"
    RAILS_LOG_TO_STDOUT      = "1"
    RAILS_SERVE_STATIC_FILES = "1"

    # DB 接続 (database.yml 参照)
    # RDS endpoint は "host:port" 形式 → host 部分のみ抽出
    DB_HOST        = split(":", aws_db_instance.main.endpoint)[0]
    MYSQL_PORT     = "3306"
    MYSQL_USER     = var.db_username
    MYSQL_DATABASE = var.db_name
    # cache / queue / cable database 名は config/database.yml の default を踏襲
    MYSQL_DATABASE_CACHE = "${var.db_name}_cache"
    MYSQL_DATABASE_QUEUE = "${var.db_name}_queue"
    MYSQL_DATABASE_CABLE = "${var.db_name}_cable"

    # CORS は CloudFront 同一オリジンで実質不要だが、preflight デバッグ用に CloudFront ドメインを明示。
    # var.cors_allowed_origins で override 可能 (独自ドメイン採用時)。
    CORS_ORIGINS = var.cors_allowed_origins != "" ? var.cors_allowed_origins : "https://${aws_cloudfront_distribution.main.domain_name}"

    # Active Storage S3 設定 (backend/config/storage.yml の amazon サービスが参照)
    S3_BUCKET = aws_s3_bucket.uploads.id
    S3_REGION = var.aws_region
  }

  # 機密パラメータ (SecureString)。
  ssm_secure_params = {
    MYSQL_PASSWORD   = var.db_password
    RAILS_MASTER_KEY = var.rails_master_key
    SECRET_KEY_BASE  = var.secret_key_base
    JWT_SECRET       = var.jwt_secret
  }
}

resource "aws_ssm_parameter" "string" {
  for_each = local.ssm_string_params

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = {
    Name = "${var.project}-${each.key}"
  }
}

resource "aws_ssm_parameter" "secure" {
  for_each = local.ssm_secure_params

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "SecureString"
  value = each.value

  tags = {
    Name = "${var.project}-${each.key}"
  }
}
