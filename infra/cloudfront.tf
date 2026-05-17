# CloudFront distribution (フロント配信 + API + 画像配信の統合エッジ)。
# docs/インフラ構成.md §2 (v0.2 ECS 構成)。
#
# 設計判断:
# - CloudFront 既定ドメイン (d12345.cloudfront.net) を使用、ACM 不要 (独自ドメイン採用時に切替)
# - PriceClass_200: 北米 + 欧州 + アジア (日本含む) で配信
# - 全 behavior で HTTPS リダイレクト強制 (HTTP は許可しない)
# - default behavior: SPA (frontend bucket)、SPA route は **403 → /index.html** で対応
#   (OAC + private bucket は AccessDenied=403 を返すため、404 書換不要)
# - /_nuxt/* 専用 behavior: Nuxt ハッシュ付きで immutable cache
# - /api/* → ALB origin、AllViewer policy で Cookie / Header 全転送 (認証必須)
# - /images/* → uploads bucket、OAC で private bucket からの取得
# - Response Headers Policy: HSTS / X-Frame-Options / Referrer-Policy 付与
# - **404 を custom_error_response に登録しない**: 書換すると /api/* の resource not found
#   404 が SPA HTML 化して JSON parse error の致命傷
# - **ALB origin が http-only (平文)**: ALB ACM 未設定時の暫定。CloudFront ↔ ALB 間で
#   Cookie / JWT が平文転送されるため独自ドメイン採用時に必ず ACM + HTTPS 化すること
#
# !!! 重要: 初回 apply の運用注意 !!!
# (1) CloudFront distribution の作成・更新は 5-15 分かかる
# (2) frontend bucket への index.html / _nuxt push をしないと CloudFront は 403 ループ
# (3) 初回 apply 後、SSM の CORS_ORIGINS を CloudFront ドメインに更新 → ECS Service 再起動:
#     aws ecs update-service --cluster trip-diary-cluster --service trip-diary-backend \
#       --force-new-deployment

# ===== Origin Access Control (OAC) =====
# OAC は IAM 認証で S3 private bucket から取得 (旧 OAI より新しい推奨方式)。

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-frontend-oac"
  description                       = "OAC for frontend SPA bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "uploads" {
  name                              = "${var.project}-uploads-oac"
  description                       = "OAC for user uploads bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ===== CloudFront Function: /images/* prefix strip =====
# Active Storage の rails_blob_path / rails_blob_url は /rails/active_storage/blobs/...
# 形式で署名付き URL を返すため、CloudFront 経由配信は当面 backend redirect で対応。
# 将来 Active Storage の url_options で CloudFront ドメインを使う場合に備えて /images/*
# behavior を用意し、prefix strip Function で実 S3 key と一致させる。
resource "aws_cloudfront_function" "strip_images_prefix" {
  name    = "${var.project}-strip-images-prefix"
  runtime = "cloudfront-js-2.0"
  comment = "Strip /images/ prefix from request URI for uploads S3 origin"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      if (request.uri.indexOf('/images/') === 0) {
        request.uri = request.uri.substring('/images'.length); // 残った先頭 / が S3 key の root
      }
      return request;
    }
  EOT
}

# ===== Response Headers Policy =====
# セキュリティヘッダ付与。CSP は誤設定でフロント白画面化するため段階導入 (本 PR では未設定)。

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project}-security-headers"
  comment = "Security headers (HSTS / X-Frame-Options / Referrer-Policy) for ${var.project}"

  security_headers_config {
    # HSTS: 1 年、subdomain 含まず、preload なし (後戻り可能性を確保)。
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }

    # X-Frame-Options: DENY (iframe 埋め込み全禁止、クリックジャッキング防止)。
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # Referrer-Policy: cross-origin では origin のみ送信。
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Content-Type sniffing 防止。
    content_type_options {
      override = true
    }
  }
}

# ===== CloudFront Distribution =====

# AWS managed policy ID (固定値、CloudFront managed)。
locals {
  cf_cache_policy_caching_optimized   = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cf_cache_policy_caching_disabled    = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cf_origin_request_policy_all_viewer = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  cf_origin_request_policy_cors_s3    = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
}

# tfsec:ignore:AVD-AWS-0011 (WAF は学習用途・無料枠重視のため未導入)
# tfsec:ignore:AVD-AWS-0010 (logging は無料枠超過リスクで未導入)
resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project} unified edge (SPA + API + images)"
  price_class     = var.cloudfront_price_class
  http_version    = "http2and3"

  # ===== Origin: フロント S3 (Nuxt SPA) =====
  origin {
    origin_id                = "frontend-s3"
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # ===== Origin: uploads S3 (user images) =====
  origin {
    origin_id                = "uploads-s3"
    domain_name              = aws_s3_bucket.uploads.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.uploads.id
  }

  # ===== Origin: ALB (backend API) =====
  # !!! セキュリティ注意: http-only は CloudFront ↔ ALB 間で Cookie / JWT が平文転送される !!!
  # ALB ACM 未設定時の暫定。独自ドメイン採用時に origin_protocol_policy="https-only" へ切替必須。
  origin {
    origin_id   = "alb-api"
    domain_name = aws_lb.main.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # 暫定、独自ドメイン採用時に https-only へ切替
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ===== Default behavior: フロント SPA (Nuxt) =====
  # index.html は no-cache (毎回最新確認)。SPA route の fallback は distribution-level
  # custom_error_response の 403 → /index.html で対応 (下記)。
  default_cache_behavior {
    target_origin_id           = "frontend-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cf_cache_policy_caching_disabled
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # ===== /_nuxt/* behavior: Nuxt ハッシュ付き静的アセット =====
  # ハッシュでバージョニングされるため immutable cache が安全。
  ordered_cache_behavior {
    path_pattern               = "/_nuxt/*"
    target_origin_id           = "frontend-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cf_cache_policy_caching_optimized
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # ===== /api/* behavior: ALB (backend API) =====
  # Cookie + Header 全転送 (JWT 認証 Cookie が ALB に届く)。
  # AllViewer policy を忘れると全リクエストが 401 になる致命的な罠。
  ordered_cache_behavior {
    path_pattern               = "/api/*"
    target_origin_id           = "alb-api"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cf_cache_policy_caching_disabled
    origin_request_policy_id   = local.cf_origin_request_policy_all_viewer
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # ===== /rails/active_storage/* behavior: ALB (Active Storage redirect) =====
  # Active Storage の rails_blob_path は /rails/active_storage/blobs/... で
  # 署名付き S3 URL への 302 redirect を返す。CloudFront 経由でも同じ挙動を期待するため
  # /api/* と同じ全転送設定で ALB に通す。
  ordered_cache_behavior {
    path_pattern               = "/rails/active_storage/*"
    target_origin_id           = "alb-api"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cf_cache_policy_caching_disabled
    origin_request_policy_id   = local.cf_origin_request_policy_all_viewer
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # ===== /images/* behavior: uploads S3 (将来の直接配信用) =====
  ordered_cache_behavior {
    path_pattern               = "/images/*"
    target_origin_id           = "uploads-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cf_cache_policy_caching_optimized
    origin_request_policy_id   = local.cf_origin_request_policy_cors_s3
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.strip_images_prefix.arn
    }
  }

  # ===== SPA fallback: 403 → /index.html のみ =====
  # custom_error_response は distribution 全体に適用されるため、404 を書換すると
  # /api/* の 404 (存在しない resource) も SPA HTML になり JSON parse error の致命傷。
  # OAC + private bucket では「存在しない object」は AccessDenied=403 を返すため
  # SPA route (/trips/123 等) は 403 経由で /index.html にフォールバック可能。
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # CloudFront 既定証明書 (cloudfront_default_certificate=true) は AWS 仕様で TLSv1 強制。
  # 独自ドメイン採用時 ACM 切替で TLSv1.2_2021 等のモダンポリシーに変更予定。
  # tfsec:ignore:aws-cloudfront-use-secure-tls-policy
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project}-distribution"
  }
}

# ===== Bucket Policy: frontend bucket OAC 経由のみ GetObject 許可 =====
resource "aws_s3_bucket_policy" "frontend_oac" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipalReadOnly"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })
}

# ===== Bucket Policy: uploads bucket OAC 経由 GetObject 追加 =====
# 既存の ECS task role による IAM 経由 PutObject/GetObject/DeleteObject は IAM 側で評価される。
resource "aws_s3_bucket_policy" "uploads_oac" {
  bucket = aws_s3_bucket.uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipalReadOnly"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.uploads.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })
}
