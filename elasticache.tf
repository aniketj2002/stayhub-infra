resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.prefix}-redis-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${var.prefix}-redis-subnet-group"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id      = "${var.prefix}-redis-cache"
  engine          = "redis"
  engine_version  = var.redis_engine_version
  node_type       = var.redis_node_type
  num_cache_nodes = 1
  port            = 6379

  preferred_availability_zones = [local.az_primary]
  subnet_group_name            = aws_elasticache_subnet_group.main.name
  security_group_ids           = [aws_security_group.redis.id]

  tags = {
    Name = "${var.prefix}-redis-cache"
  }
}
