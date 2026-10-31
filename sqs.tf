# SQS Dead Letter Queue for failed payout releases
resource "aws_sqs_queue" "payout_dlq" {
  name                      = "${var.prefix}-payout-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "${var.prefix}-payout-dlq"
  }
}

# SQS Queue for EventBridge Scheduler payout release events
resource "aws_sqs_queue" "payout" {
  name                       = "${var.prefix}-payout-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600 # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payout_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.prefix}-payout-queue"
  }
}

# IAM Role assumed by EventBridge Scheduler to deliver messages to SQS
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.prefix}-scheduler-execution-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json

  tags = {
    Name = "${var.prefix}-scheduler-execution-role"
  }
}

data "aws_iam_policy_document" "scheduler_sqs_send" {
  statement {
    sid       = "AllowEventBridgeToSQSPayoutQueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.payout.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_sqs" {
  name   = "${var.prefix}-scheduler-sqs-policy"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_sqs_send.json
}

# IAM Policy for ECS Tasks to interact with EventBridge Scheduler and SQS
data "aws_iam_policy_document" "ecs_task_payouts" {
  statement {
    sid    = "AllowManageEventBridgePayoutSchedules"
    effect = "Allow"
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:DeleteSchedule",
      "scheduler:GetSchedule",
      "scheduler:UpdateSchedule",
    ]
    resources = [
      "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule/*/*",
      "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule/default/*"
    ]
  }

  statement {
    sid    = "AllowPassRoleToScheduler"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [aws_iam_role.scheduler.arn]
  }

  statement {
    sid    = "AllowSQSPayoutQueueOperations"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [aws_sqs_queue.payout.arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_payouts" {
  name   = "${var.prefix}-ecs-task-payouts-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_payouts.json
}
