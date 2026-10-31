output "app_url" {
  description = "Live HTTPS URL for the StayHub web application (CloudFront)"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "guest_url" {
  description = "Guest Explore & Search URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/search"
}

output "host_url" {
  description = "Host Dashboard & Listings URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/host/listings"
}

output "admin_login_url" {
  description = "Admin Portal Login URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/admin/login"
}

output "system_health_url" {
  description = "System Health UI URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/system"
}

output "api_healthz_url" {
  description = "Backend API /healthz endpoint URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/healthz"
}

output "events_api_url" {
  description = "Platform Audit Event Log API URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/api/v1/events"
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS Name"
  value       = aws_lb.main.dns_name
}

output "frontend_s3_bucket" {
  description = "S3 Bucket Name for Frontend Static Build"
  value       = aws_s3_bucket.frontend.bucket
}

output "media_s3_bucket" {
  description = "S3 Bucket Name for Media Storage"
  value       = aws_s3_bucket.media.bucket
}

output "ecr_api_repository_url" {
  description = "ECR Repository URL for Backend API"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_worker_repository_url" {
  description = "ECR Repository URL for Backend Worker"
  value       = aws_ecr_repository.worker.repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_api_service_name" {
  description = "ECS API Service Name"
  value       = aws_ecs_service.api.name
}

output "ecs_worker_service_name" {
  description = "ECS Worker Service Name"
  value       = aws_ecs_service.worker.name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL Endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis Endpoint"
  value       = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"
}

output "payout_queue_url" {
  description = "SQS Payout Queue URL"
  value       = aws_sqs_queue.payout.url
}

output "payout_queue_arn" {
  description = "SQS Payout Queue ARN"
  value       = aws_sqs_queue.payout.arn
}

output "payout_dlq_url" {
  description = "SQS Payout Dead Letter Queue URL"
  value       = aws_sqs_queue.payout_dlq.url
}

output "eventbridge_scheduler_role_arn" {
  description = "IAM Role ARN for EventBridge Scheduler Target"
  value       = aws_iam_role.scheduler.arn
}

output "ses_sender_email" {
  description = "SES Verified Sender Email Identity"
  value       = aws_ses_email_identity.sender.email
}
