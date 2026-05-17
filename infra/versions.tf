# Terraform / Provider バージョン制約と AWS Provider 設定。
#
# tfstate backend: S3 (姉妹 PJ sns-board と同方針)。
# Lock 方式は S3 native lockfile (use_lockfile=true、Terraform 1.10+)。
#
# !!! 初回 apply 前の準備 !!!
# 以下のリソースを AWS Console / aws CLI で手動作成しておくこと:
#   1. S3 bucket "trip-diary-tfstate"
#      - リージョン: ap-northeast-1
#      - Block Public Access: 全 ON
#      - Versioning: Enabled
#      - SSE-S3 (AES256) 有効
#   2. (任意) bucket policy で誤削除防止 (本番昇格時)

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "trip-diary-tfstate"
    key          = "phase3/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
