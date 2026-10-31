# stayhub-infra

Terraform Infrastructure as Code (IaC) for **StayHub** on AWS.

## Architecture & Resources
- **Single-Region (`us-east-1`)**, Single-AZ, lowest available machine tiers.
- All resources prefixed with **`aniket-`**:
  - `aniket-vpc`: Custom VPC (`10.0.0.0/16`) with public & private subnets.
  - `aniket-rds-postgres`: RDS PostgreSQL 15, `db.t4g.micro`, Single-AZ, 20GB gp3.
  - `aniket-redis-cache`: ElastiCache Redis 7.1, `cache.t4g.micro`, 1 node.
  - `aniket-stayhub-frontend-<account_id>`: Private S3 bucket with CloudFront OAC.
  - `aniket-stayhub-media-<account_id>`: Private S3 bucket for media & photos.
  - `aniket-cf-distribution`: CloudFront CDN with `/api/*` and `/healthz` reverse-proxy to ALB.
  - `aniket-alb` & `aniket-tg-api`: Ingress load balancer on port 8080.
  - `aniket-ecs-cluster`, `aniket-api-service`, `aniket-worker-service`: ECS Fargate tasks (0.25 vCPU, 0.5 GB RAM).
  - `aniket-ecr-api`, `aniket-ecr-worker`: Container registries.
  - `/aniket/stayhub/*`: SSM Parameter Store `SecureString` KMS-encrypted secrets.

## Prerequisites
- AWS CLI v2 (`brew install awscli`) authenticated with `aws sts get-caller-identity`
- OpenTofu or Terraform (`brew install opentofu` OR `brew tap hashicorp/tap && brew install hashicorp/tap/terraform`)
- Docker (running)

## One-Command Deploy & Teardown
```bash
./deploy.sh
```
To tear down all resources when finished:
```bash
./destroy.sh
```
