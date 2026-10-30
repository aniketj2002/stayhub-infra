resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${var.prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.prefix}-rds-postgres"
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # Single-AZ / Non-HA per specification
  multi_az               = false
  availability_zone      = local.az_primary
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Fast single-command tear-down with zero stranded snapshots
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
  apply_immediately       = true

  tags = {
    Name = "${var.prefix}-rds-postgres"
  }
}
