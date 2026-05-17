# CloudWatch Logs ロググループ。
# docs/ログ・監視・障害対応設計書.md §5-4 (CloudWatch 連携)。
#
# ECS Fargate の awslogs ドライバが Rails container の STDOUT をこのロググループへ転送する。
# ロググループを明示定義することで保持期間 (コスト) を制御する
# (ドライバ任せだと無期限保持になり無料枠を超過しうる)。

# KMS CMK 暗号化は無料枠ポリシーの範囲外のため未使用。
# CloudWatch Logs はデフォルトでサーバー側暗号化される。
# tfsec:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "backend" {
  name = "/${var.project}/backend/prod"

  # 学習用途・無料枠重視のため 7 日保持 (無料枠は 5GB 取込/月)。
  retention_in_days = 7

  tags = {
    Name = "${var.project}-backend-logs"
  }
}

# CloudWatch アラーム (Phase B で追加予定):
# - ECS CPU > 80% / 5 分間
# - ALB Target 5XX 急増
# - RDS FreeStorageSpace 残 < 2GB
# - RDS WriteIOPS / ReadIOPS 高水準
# 現状は log group のみで運用 (アラート無し)。
