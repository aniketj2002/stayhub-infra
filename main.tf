provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "${var.prefix}-${var.project_name}"
      Environment = var.app_env
      Owner       = var.prefix
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix  = var.prefix
  account_id   = data.aws_caller_identity.current.account_id
  az_primary   = data.aws_availability_zones.available.names[0]
  az_secondary = data.aws_availability_zones.available.names[1]
}
