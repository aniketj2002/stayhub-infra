# SES Email Identity for Outbound Platform Emails
resource "aws_ses_email_identity" "sender" {
  email = "aniketjindal2002@gmail.com"
}

# IAM Policy document for sending outbound emails via AWS SES
data "aws_iam_policy_document" "ses_send_email" {
  statement {
    sid    = "AllowSendEmailViaSES"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
      "ses:GetIdentityVerificationAttributes",
    ]
    resources = ["*"]
  }
}

# Attach SES send policy to ECS Task Role (Fargate container runtime)
resource "aws_iam_role_policy" "ecs_task_ses" {
  name   = "${var.prefix}-ecs-task-ses-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ses_send_email.json
}

# Attach SES send policy to media_s3 IAM user (covers S3_ACCESS_KEY credentials provider)
resource "aws_iam_user_policy" "media_s3_ses" {
  name   = "${var.prefix}-media-s3-ses-policy"
  user   = aws_iam_user.media_s3.name
  policy = data.aws_iam_policy_document.ses_send_email.json
}
