# RDS MySQL 8.0。Rails 8.1 + mysql2 gem。
# docs/インフラ構成.md §2 (v0.2 ECS 構成)。
#
# !!! 重要: Rails 8 Solid stack (cache / queue / cable) について !!!
# Rails 8 はデフォルトで cache / queue / cable に別データベースを使う構成
# (config/database.yml の production 参照)。RDS インスタンス 1 個に 4 つの
# データベース (primary + cache + queue + cable) を作成する。
#   - aws_db_instance.db_name は primary (trip_diary_prod) のみを作成
#   - 残り 3 つ (trip_diary_prod_cache / _queue / _cable) は初回 apply 後に
#     手動で `CREATE DATABASE` を発行する (README §運用 Runbook 参照)
# 自動化は別 PR (init container / null_resource 等) で検討。

# DB Subnet Group: RDS は最低 2 AZ のサブネットを要求するため A / C をまとめる
# (RDS 自体は Single-AZ で az_a に配置される)。
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_c.id]

  tags = {
    Name = "${var.project}-db-subnet-group"
  }
}

# tfsec:ignore:AVD-AWS-0176
resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.rds_instance_class

  # 無料枠: 20GB ストレージ。gp3 + 保存時暗号化。
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # パブリック経路を作らない。到達は ECS task SG 参照のみ (network.tf)。
  publicly_accessible = false

  # 自動バックアップの保持期間 (tfsec AVD-AWS-0177)。
  # Free Tier は backup retention 最大 1 日 (>1 で FreeTierRestrictionError)。
  # 学習用途のためデモ後 tear-down 前提で 1 日に縮小。
  backup_retention_period = 1

  # 無料枠維持: Single-AZ / Performance Insights 無効。
  multi_az = false
  # tfsec:ignore:AVD-AWS-0133
  performance_insights_enabled = false

  # 学習用の tear-down 撤収方針のため最終スナップショット skip +
  # deletion protection 無効。本番運用では skip_final_snapshot=false /
  # deletion_protection=true にする。
  skip_final_snapshot = true
  # tfsec:ignore:AVD-AWS-0177
  deletion_protection = false

  tags = {
    Name = "${var.project}-db"
  }
}
