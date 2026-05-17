# VPC / Subnet / IGW / Route Table / Security Group。
# 設計: docs/インフラ構成.md §2 (v0.2 ECS 構成)。
#
# 「セミ・パブリック構成」: NAT Gateway の月額課金 ($30/月〜) を避けるため
# プライベートサブネットを設けず、ECS Fargate task はパブリックサブネットに配置
# (assign_public_ip=true で ECR / SSM / S3 / CloudWatch Logs へ通信)。
# RDS は publicly_accessible=false + SG 参照で到達制御する (rds.tf)。

# ===== VPC =====

# VPC Flow Logs は学習用・無料枠重視のため未導入。
# tfsec:ignore:AVD-AWS-0178
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

# ===== パブリックサブネット (ECS Fargate task + ALB を A/C 2 AZ で配置) =====

# tfsec:ignore:AVD-AWS-0164
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-a"
  }
}

# tfsec:ignore:AVD-AWS-0164
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_c_cidr
  availability_zone       = var.az_c
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-c"
  }
}

# ===== Internet Gateway + Route Table =====

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# ===== Security Group =====
# ECS task SG: ALB SG からの port 3000 ingress のみ許可 (Thruster non-privileged port
#   / rule は循環参照回避のため aws_security_group_rule で別リソース化、alb.tf 参照)。
#   egress は ECR (443) / SSM (443) / S3 (443) / RDS (3306) / CloudWatch Logs (443)
#   への必要通信のため all 許可。
resource "aws_security_group" "ecs_task" {
  name        = "${var.project}-ecs-task-sg"
  description = "ECS Fargate task SG for ${var.project}"
  vpc_id      = aws_vpc.main.id

  # NAT Gateway なし構成のため ECS task は IGW 経由で AWS API (ECR/SSM/S3/Logs) と
  # RDS 内部通信 (egress=all で自動許可) を行う。
  # tfsec:ignore:AVD-AWS-0104
  egress {
    description = "all outbound (ECR pull, SSM, S3, RDS, CloudWatch Logs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-ecs-task-sg"
  }
}

# RDS SG: MySQL (3306) を ECS task SG 所属の Fargate task からのみ許可 (SG 参照)。
# CIDR ではなく SG ID 参照にすることで「ECS task 以外からは到達不可」を担保。
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS MySQL SG for ${var.project}"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS task SG only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }

  # egress は意図的に定義しない。RDS は外向き通信を行わず、ingress に対する
  # 応答は stateful SG が自動で許可するため egress ルールは不要 (最小権限)。

  tags = {
    Name = "${var.project}-rds-sg"
  }
}
