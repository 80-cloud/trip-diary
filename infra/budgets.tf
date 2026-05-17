# AWS Budgets で trip-diary 専用の月次コスト監視を行う。
#
# タグフィルタ Project=trip-diary は versions.tf の default_tags と完全一致させる必要が
# ある (大文字小文字を含む literal 一致)。
#
# Budgets は Free Tier で 2 budget まで無料。
#
# !!! 初回 apply 時の subscriber 確認メールに注意 !!!
# 初回 apply 後、AWS から subscriber email に "AWS Notification - Subscription
# Confirmation" メールが届く。リンクを開いて confirm するまで通知は到達しない。
# "apply したのに通知来ない" と勘違いしないこと (Terraform 側からは confirm 状況は不可視)。

resource "aws_budgets_budget" "monthly_cost" {
  # name に金額 ($30 等) を含めると budget_limit_usd 変更時に name 変更 →
  # 削除＋再作成 → subscriber confirm メール再送 → 確認するまで通知断絶になる。
  # 金額に依存しない name で再作成を避ける。
  name         = "${var.project}-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # AWS Budgets のタグフィルタは "user:KEY$VALUE" 形式 (user: prefix はユーザータグの意)。
  # `$` は Terraform 補間 `${}` と衝突するため format() で組み立てる ($${} だと literal
  # `${var.project}` になり変数展開されない罠あり)。
  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Project$%s", var.project)]
  }

  # しきい値 1: 実コスト 80% 到達で警告 (早期検知)。
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  # しきい値 2: 実コスト 100% 到達で警告 (上限突破)。
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  # しきい値 3: 予測値ベース 100% 到達で警告 (月末を待たずに pace 異常を検知)。
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
