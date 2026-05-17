# フロント配信用 S3 bucket (CloudFront default origin)。
# Nuxt SPA build (`npm run build` または `npm run generate`) の出力を sync する。
# docs/インフラ構成.md §2 (v0.2 ECS 構成)。
#
# 設計判断 (uploads bucket と同方針):
# - Public Block 全有効 (CloudFront OAC 経由のみアクセス可)
# - SSE-S3 (AES256): KMS CMK は無料枠外
# - Versioning 有効 (誤削除復元、index.html ロールバック容易化)
# - bucket policy は cloudfront.tf に集約 (CloudFront ARN 参照のため)

# tfsec:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend-${data.aws_caller_identity.current.account_id}"

  force_destroy = var.force_destroy_resources

  tags = {
    Name = "${var.project}-frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# tfsec:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}
