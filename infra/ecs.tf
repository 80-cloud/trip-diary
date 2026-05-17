# ECS Fargate Cluster / Task Definition / Service。Phase 3 で Rails を稼働。
# docs/インフラ構成.md §2-4 (v0.2 ECS 構成)。
#
# 設計判断:
# - capacity_provider = FARGATE_SPOT: 最大 70% 割引、月 ~$3
#   2 分前通知で中断あり。デモ運用に適する
# - cpu/memory = 256/1024 (Fargate 最小 CPU、Rails + bootsnap + jemalloc + image_processing
#   で 512MB は起動失敗リスクあり、1024MB に拡大)
# - network_mode = awsvpc (Fargate 強制、ENI 直結で SG 制御可能)
# - public subnet + assign_public_ip=true: NAT Gateway ($30/月) 回避、ingress は SG で制限
# - SSM 全パラメータを secrets[].valueFrom で参照: tfstate に値が乗らず、SSM 更新で適用反映
# - desired_count=1: 学習用途
#
# !!! 初回 apply の手順 (scripts/deploy-backend.sh に集約予定) !!!
# (1) terraform apply で ECR repository / ECS Service / ALB 等を一斉作成
#     (ECS Service は image pull で ImagePullError になるが Service 自体は作成完了)
# (2) ./scripts/deploy-backend.sh を実行 (Docker build + ECR push + Task Def 更新 + rolling restart)
#
# !!! 重要: SSM 値変更時の再反映 !!!
# task_definition の変更 (container image tag / env / secrets ARN) は Service が rolling update
# で自動反映するが、SSM parameter の値変更は Service 再起動を別途トリガする必要あり
# (aws ecs update-service --force-new-deployment)。

# Container Insights は CloudWatch カスタムメトリクス課金あり (無料枠超過リスク)。
# tfsec:ignore:aws-ecs-enable-container-insight
resource "aws_ecs_cluster" "app" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.project}-cluster"
  }
}

# Capacity provider 紐付け。FARGATE_SPOT を既定にすることでデモ運用時の課金を約 70% 削減。
resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name       = aws_ecs_cluster.app.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.ecs_task_cpu)
  memory                   = tostring(var.ecs_task_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true

      # Rails Dockerfile は Thruster 経由で port 3000 を expose (Issue #61)。
      # 旧 80 だと non-root container で privileged port bind 失敗 (permission denied)。
      # Thruster (3000) → Rails puma (3001) の 2 段構成。
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      # environment: SSM に置けない / static な値はここで直接渡す。
      # HTTP_PORT: Thruster がリッスンする public 側 port (非 privileged)。
      # TARGET_PORT: Thruster が proxy 先の Rails puma が listen する内部 port。
      environment = [
        { name = "HTTP_PORT", value = "3000" },
        { name = "TARGET_PORT", value = "3001" }
      ]

      # 全 SSM パラメータ (String + SecureString) を valueFrom 参照で注入。
      # execution_role が SSM:GetParameters + KMS Decrypt 権限を持つ (iam.tf)。
      # Task Definition に値が埋め込まれないため tfstate に機密が漏れない。
      secrets = concat(
        [for k in keys(local.ssm_string_params) : {
          name      = k
          valueFrom = aws_ssm_parameter.string[k].arn
        }],
        [for k in keys(local.ssm_secure_params) : {
          name      = k
          valueFrom = aws_ssm_parameter.secure[k].arn
        }]
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project}-backend-taskdef"
  }
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project}-backend"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1

  # launch_type と capacity_provider_strategy は相互排他。Spot 化のため strategy を採用。
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }

  # rolling update: 一時的に 200% (新旧 2 task 並行) で 0 ダウン目指す。
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_c.id]
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "backend"
    container_port   = 3000
  }

  # ALB target が healthy 認定されるまで猶予。Fargate 256 CPU での Rails + bootsnap 起動
  # を考慮し 180s に拡大 (60s では起動中に unhealthy 判定で再起動ループの恐れあり)。
  health_check_grace_period_seconds = 180

  # 暗黙参照 (task_definition / target_group / SG) に加え、以下を明示依存:
  # - IAM policy: Service 起動時の IAM 伝播待ちで CreateService が fail する罠を回避
  # - SG rule (ALB→task の port 3000 ingress): Service 起動 → ALB health check 開始時点で
  #   rule が無いと最初の health check が連続失敗 → unhealthy で task 再起動ループ
  depends_on = [
    aws_iam_role_policy.ecs_task_execution_ssm,
    aws_iam_role_policy.ecs_task_execution_logs,
    aws_iam_role_policy.ecs_task_execution_ecr,
    aws_iam_role_policy.ecs_task_s3_uploads,
    aws_security_group_rule.ecs_task_from_alb,
    # capacity provider が cluster に登録される前に Service を作ると
    # InvalidParameterException が出る。
    aws_ecs_cluster_capacity_providers.app,
  ]

  tags = {
    Name = "${var.project}-backend-service"
  }
}
