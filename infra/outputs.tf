# apply 後に参照する値の出力。
# scripts/deploy-backend.sh / scripts/deploy-frontend.sh から `terraform output` で取得。

output "vpc_id" {
  description = "作成された VPC の ID"
  value       = aws_vpc.main.id
}

output "ecs_cluster_name" {
  description = "ECS cluster 名 (aws ecs update-service 等で使用)"
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS Service 名 (aws ecs update-service / describe-services で使用)"
  value       = aws_ecs_service.backend.name
}

output "ecr_repository_url" {
  description = "Backend image push 先 (docker tag <local> <url>:<sha> && docker push <url>:<sha>)"
  value       = aws_ecr_repository.backend.repository_url
}

output "rds_endpoint" {
  description = "RDS のエンドポイント (host:port)。アプリの DB_HOST 組立に使う"
  value       = aws_db_instance.main.endpoint
}

output "rds_db_name" {
  description = "RDS の初期データベース名 (primary)"
  value       = aws_db_instance.main.db_name
}

output "s3_bucket_name" {
  description = "画像アップロード用 S3 バケット名 (Active Storage の S3_BUCKET env)"
  value       = aws_s3_bucket.uploads.id
}

output "alb_dns_name" {
  description = "ALB の DNS 名。CloudFront の Origin として参照済、独自ドメイン採用時は Route 53 A エイリアスを CloudFront に向ける"
  value       = aws_lb.main.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront 既定ドメイン (d12345.cloudfront.net 形式)。フロント / API / 画像配信の統合エッジ URL"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (デプロイ時 invalidation 対象、aws cloudfront create-invalidation --distribution-id)"
  value       = aws_cloudfront_distribution.main.id
}

output "frontend_bucket_name" {
  description = "フロント SPA 配信用 S3 バケット名 (npm run build && aws s3 sync .output/public/ s3://<this>/ 対象)"
  value       = aws_s3_bucket.frontend.id
}

output "backend_log_group" {
  description = "Backend ログの CloudWatch ロググループ名"
  value       = aws_cloudwatch_log_group.backend.name
}

output "ssm_parameter_prefix" {
  description = "アプリ設定が格納される SSM Parameter Store の prefix"
  value       = local.ssm_prefix
}
