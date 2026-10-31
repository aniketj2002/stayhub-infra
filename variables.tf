variable "prefix" {
  description = "Resource naming prefix applied to all AWS resources"
  type        = string
  default     = "aniket"
}

variable "project_name" {
  description = "Application name"
  type        = string
  default     = "stayhub"
}

variable "aws_region" {
  description = "Single AWS region for deployment (multi-region is out of scope per spec)"
  type        = string
  default     = "us-east-1"
}

variable "app_env" {
  description = "Application runtime environment"
  type        = string
  default     = "production"
}

variable "version_mode" {
  description = "StayHub version mode ('v1' auto-approves listings passing automated checks; 'v2' queues for admin review)"
  type        = string
  default     = "v1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "Minimum available RDS PostgreSQL instance class (Free Tier eligible)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Minimum RDS allocated storage in GB (gp3)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine major/minor version"
  type        = string
  default     = "15"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "stayhub"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "aniket_admin"
}

variable "redis_node_type" {
  description = "Minimum available ElastiCache Redis node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "ecs_api_cpu" {
  description = "Minimum Fargate CPU units for API task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_api_memory" {
  description = "Minimum Fargate memory in MiB for API task (512 = 0.5 GB)"
  type        = number
  default     = 512
}

variable "ecs_worker_cpu" {
  description = "Minimum Fargate CPU units for Worker task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_worker_memory" {
  description = "Minimum Fargate memory in MiB for Worker task (512 = 0.5 GB)"
  type        = number
  default     = 512
}

variable "api_image_tag" {
  description = "Docker image tag for the API service in ECR"
  type        = string
  default     = "latest"
}

variable "worker_image_tag" {
  description = "Docker image tag for the Worker service in ECR"
  type        = string
  default     = "latest"
}

variable "auto_migrate" {
  description = "Automatically apply SQL migrations when the API container starts"
  type        = bool
  default     = true
}

variable "auto_seed" {
  description = "Automatically run idempotent sample data seed when the API container starts"
  type        = bool
  default     = true
}
