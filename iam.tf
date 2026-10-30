resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

# Least-privilege IAM user for S3 SigV4 presigned URLs & server-side media uploads
resource "aws_iam_user" "media_s3" {
  name          = "${var.prefix}-media-s3-user"
  force_destroy = true

  tags = {
    Name = "${var.prefix}-media-s3-user"
  }
}

data "aws_iam_policy_document" "media_s3_access" {
  statement {
    sid       = "LeastPrivilegeMediaBucketObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.media.arn}/*"]
  }

  statement {
    sid       = "LeastPrivilegeMediaBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.media.arn]
  }
}

resource "aws_iam_user_policy" "media_s3" {
  name   = "${var.prefix}-media-s3-policy"
  user   = aws_iam_user.media_s3.name
  policy = data.aws_iam_policy_document.media_s3_access.json
}

resource "aws_iam_access_key" "media_s3" {
  user = aws_iam_user.media_s3.name
}

# SSM Parameter Store Secrets (Secrets kept outside repository)
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.prefix}/${var.project_name}/db-password"
  description = "StayHub RDS PostgreSQL master password"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = {
    Name = "${var.prefix}-ssm-db-password"
  }
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.prefix}/${var.project_name}/database-url"
  description = "StayHub PostgreSQL connection URI"
  type        = "SecureString"
  value       = "postgres://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.postgres.endpoint}/${var.db_name}?sslmode=require"

  tags = {
    Name = "${var.prefix}-ssm-database-url"
  }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.prefix}/${var.project_name}/jwt-secret"
  description = "StayHub HMAC-SHA256 JWT signing secret"
  type        = "SecureString"
  value       = random_password.jwt_secret.result

  tags = {
    Name = "${var.prefix}-ssm-jwt-secret"
  }
}

resource "aws_ssm_parameter" "s3_access_key" {
  name        = "/${var.prefix}/${var.project_name}/s3-access-key"
  description = "StayHub S3 media access key ID"
  type        = "SecureString"
  value       = aws_iam_access_key.media_s3.id

  tags = {
    Name = "${var.prefix}-ssm-s3-access-key"
  }
}

resource "aws_ssm_parameter" "s3_secret_key" {
  name        = "/${var.prefix}/${var.project_name}/s3-secret-key"
  description = "StayHub S3 media secret access key"
  type        = "SecureString"
  value       = aws_iam_access_key.media_s3.secret

  tags = {
    Name = "${var.prefix}-ssm-s3-secret-key"
  }
}

# ECS Task Execution Role (Pulls ECR images, writes logs, injects SSM secrets)
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_exec" {
  name               = "${var.prefix}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.prefix}-ecs-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_exec_ssm" {
  statement {
    sid     = "LeastPrivilegeReadStayHubParameters"
    effect  = "Allow"
    actions = ["ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.db_password.arn,
      aws_ssm_parameter.database_url.arn,
      aws_ssm_parameter.jwt_secret.arn,
      aws_ssm_parameter.s3_access_key.arn,
      aws_ssm_parameter.s3_secret_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_exec_ssm" {
  name   = "${var.prefix}-ecs-ssm-secrets-policy"
  role   = aws_iam_role.ecs_exec.id
  policy = data.aws_iam_policy_document.ecs_exec_ssm.json
}

# ECS Task Role (Application runtime least-privilege access to media S3 bucket)
resource "aws_iam_role" "ecs_task" {
  name               = "${var.prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.prefix}-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name   = "${var.prefix}-ecs-task-s3-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.media_s3_access.json
}
