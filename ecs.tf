resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.prefix}-ecs-cluster"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.prefix}-api"
  retention_in_days = 7

  tags = {
    Name = "${var.prefix}-logs-api"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.prefix}-worker"
  retention_in_days = 7

  tags = {
    Name = "${var.prefix}-logs-worker"
  }
}

locals {
  common_container_env = [
    { name = "APP_ENV", value = var.app_env },
    { name = "HTTP_PORT", value = "8080" },
    { name = "CORS_ALLOWED_ORIGINS", value = "https://${aws_cloudfront_distribution.main.domain_name}" },
    { name = "REDIS_ADDR", value = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}" },
    { name = "REDIS_DB", value = "0" },
    { name = "JWT_ACCESS_TTL_MINUTES", value = "60" },
    { name = "JWT_REFRESH_TTL_DAYS", value = "30" },
    { name = "S3_REGION", value = var.aws_region },
    { name = "S3_BUCKET", value = aws_s3_bucket.media.bucket },
    { name = "S3_ENDPOINT", value = "https://s3.${var.aws_region}.amazonaws.com" },
    { name = "S3_PUBLIC_BASE_URL", value = "https://${aws_cloudfront_distribution.main.domain_name}" },
    { name = "S3_USE_PATH_STYLE", value = "false" },
    { name = "DEFAULT_CURRENCY", value = "EUR" },
    { name = "GUEST_FEE_BPS", value = "1400" },
    { name = "HOST_FEE_BPS", value = "300" },
    { name = "REQUEST_EXPIRY_HOURS", value = "24" },
    { name = "PAYOUT_RELEASE_AFTER_CHECKIN_HOURS", value = "24" },
    { name = "STAYHUB_VERSION_MODE", value = var.version_mode },
    { name = "AUTO_MIGRATE", value = tostring(var.auto_migrate) },
    { name = "AUTO_SEED", value = tostring(var.auto_seed) },
  ]

  common_container_secrets = [
    { name = "DATABASE_URL", valueFrom = aws_ssm_parameter.database_url.arn },
    { name = "JWT_SECRET", valueFrom = aws_ssm_parameter.jwt_secret.arn },
    { name = "S3_ACCESS_KEY", valueFrom = aws_ssm_parameter.s3_access_key.arn },
    { name = "S3_SECRET_KEY", valueFrom = aws_ssm_parameter.s3_secret_key.arn },
  ]
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.prefix}-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs_api_cpu)
  memory                   = tostring(var.ecs_api_memory)
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "${var.prefix}-api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.api_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = local.common_container_env
      secrets     = local.common_container_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.prefix}-api-task"
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.prefix}-worker-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs_worker_cpu)
  memory                   = tostring(var.ecs_worker_memory)
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name        = "${var.prefix}-worker"
      image       = "${aws_ecr_repository.worker.repository_url}:${var.worker_image_tag}"
      essential   = true
      environment = local.common_container_env
      secrets     = local.common_container_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.prefix}-worker-task"
  }
}

resource "aws_ecs_service" "api" {
  name                              = "${var.prefix}-api-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [aws_subnet.public_a.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${var.prefix}-api"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.ecs_exec_ssm,
  ]

  tags = {
    Name = "${var.prefix}-api-service"
  }
}

resource "aws_ecs_service" "worker" {
  name            = "${var.prefix}-worker-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy.ecs_exec_ssm,
  ]

  tags = {
    Name = "${var.prefix}-worker-service"
  }
}
