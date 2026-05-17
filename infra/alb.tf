# Application Load Balancer。
# docs/インフラ構成.md §2 (v0.2 ECS 構成)。
#
# ACM 証明書は acm_certificate_arn 変数で受け取る (証明書発行 + ドメイン取得 +
# Route 53 は別 PR / 手動オペレーション)。
#   - acm_certificate_arn が空: HTTP リスナーのみ (TG へ forward)
#   - acm_certificate_arn 指定: HTTPS リスナー + HTTP→HTTPS リダイレクト
#
# ターゲットは ECS Fargate task の ENI:3000 (target_type=ip / Thruster non-privileged port)。
# ECS Service が自動で target 登録/解除を担当するため target_group_attachment は不要。

# ALB SG: 443 / 80 をインターネットに公開。
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB SG for ${var.project}"
  vpc_id      = aws_vpc.main.id

  # ALB は公開 Web サービスのエントリポイント。
  # tfsec:ignore:AVD-AWS-0107
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # tfsec:ignore:AVD-AWS-0107
  ingress {
    description = "HTTP from internet (redirected to HTTPS when ACM is set)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # tfsec:ignore:AVD-AWS-0104 ALB から ECS task への転送に必要。
  egress {
    description = "to ECS task targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-alb-sg"
  }
}

# ECS task SG への port 3000 ingress (ALB SG からのみ)。Fargate task の ENI へ転送。
# port 3000: Thruster が非 privileged port で listen (Issue #61)。non-root container では
# port 80 (privileged) に bind 不可のため。
# aws_security_group_rule で別リソース化し、ecs_task SG と alb SG の循環参照を回避する。
resource "aws_security_group_rule" "ecs_task_from_alb" {
  type                     = "ingress"
  description              = "Rails HTTP from ALB only"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_task.id
  source_security_group_id = aws_security_group.alb.id
}

# ALB は公開 Web サービスのエントリポイントのため internal=false は仕様。
# tfsec:ignore:AVD-AWS-0053
resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]

  # リクエストスマグリング対策: 不正なヘッダーフィールドを破棄する。
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project}-alb"
  }
}

# target_type=ip: Fargate task の ENI IP に直接ルーティング (instance type は EC2 専用)。
# target 登録/解除は ECS Service が自動管理 (target_group_attachment 不要)。
resource "aws_lb_target_group" "app" {
  name        = "${var.project}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/api/v1/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # task drain 時の deregistration 待ち時間 (default 300s)。Fargate は新 task 起動
  # が速いため短縮しても安全。
  deregistration_delay = 30

  tags = {
    Name = "${var.project}-tg"
  }
}

# HTTP リスナー。ACM 証明書があれば HTTPS へリダイレクト、無ければ TG へ forward。
# tfsec:ignore:AVD-AWS-0054
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.acm_certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }

  dynamic "default_action" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# HTTPS リスナー。ACM 証明書 ARN が指定された時のみ作成。
resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
