# 画像アップロード用 S3 バケット (Active Storage の :amazon サービス)。
# docs/インフラ構成.md §2 (v0.2 ECS 構成)。
#
# パブリックアクセスは全ブロック。配信は CloudFront OAC 経由 (cloudfront.tf)。

# バケットアクセスログは学習用・無料枠重視のため未導入。
# tfsec:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "uploads" {
  bucket = var.s3_bucket_name

  # デモ apply→tear-down 運用時に true。default false で本番安全側。
  # 注意: versioning enabled のため noncurrent version も同時削除される。
  force_destroy = var.force_destroy_resources

  tags = {
    Name = var.s3_bucket_name
  }
}

# パブリックアクセスを全ブロック。
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# サーバー側暗号化 (SSE-S3)。
# KMS CMK ではなく SSE-S3 (AES256) を採用: KMS CMK は鍵の月額 + リクエスト課金が無料枠外。
# tfsec:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# バージョニング有効 (誤削除からの復元)。
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CORS 設定: Active Storage の direct upload (presigned URL POST) で必要。
# 本構成では backend 経由のアップロードのみ想定だが、将来の direct upload に備えて
# CloudFront ドメインからの PUT / POST を許可。
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_methods = ["GET", "HEAD", "PUT", "POST"]
    allowed_origins = var.cors_allowed_origins != "" ? split(",", var.cors_allowed_origins) : ["https://${aws_cloudfront_distribution.main.domain_name}"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag", "x-amz-version-id"]
    max_age_seconds = 3000
  }
}
