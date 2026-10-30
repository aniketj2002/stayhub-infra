resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

# Public Subnets (ALB requires 2 AZs; ECS tasks run in primary AZ with SG restricting inbound solely to ALB)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az_primary
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-public-1a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = local.az_secondary
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-public-1b"
  }
}

# Private Data Subnets (RDS subnet group requires 2 AZs; Single-AZ RDS & Single-Node Redis run in primary AZ)
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = local.az_primary
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.prefix}-subnet-private-1a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = local.az_secondary
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.prefix}-subnet-private-1b"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-rt-private"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security Group: Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.prefix}-alb-sg"
  description = "Allow HTTP ingress from CloudFront / internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from CloudFront and internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to ECS containers on 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.prefix}-alb-sg"
  }
}

# Security Group: ECS Fargate Tasks (API & Worker)
resource "aws_security_group" "ecs" {
  name        = "${var.prefix}-ecs-sg"
  description = "Allow HTTP 8080 strictly from ALB; allow outbound to DB, Redis, S3, and ECR"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP 8080 strictly from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound to RDS, Redis, ECR, S3, and CloudWatch"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-ecs-sg"
  }
}

# Security Group: RDS PostgreSQL
resource "aws_security_group" "rds" {
  name        = "${var.prefix}-rds-sg"
  description = "Allow PostgreSQL 5432 strictly from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${var.prefix}-rds-sg"
  }
}

# Security Group: ElastiCache Redis
resource "aws_security_group" "redis" {
  name        = "${var.prefix}-redis-sg"
  description = "Allow Redis 6379 strictly from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from ECS tasks only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${var.prefix}-redis-sg"
  }
}
