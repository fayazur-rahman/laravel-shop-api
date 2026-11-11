# ─── Firewall: Redis only from the web tasks ────────────────────────────────

resource "aws_security_group" "cache" {
  name        = "${local.name}-cache"
  description = "ElastiCache Redis: 6379 from the web tasks only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "cache_redis_from_web" {
  security_group_id            = aws_security_group.cache.id
  description                  = "Redis only from the web tasks"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

# No egress rule on purpose: Redis only answers connections, and security
# groups are stateful, so replies leave without an outbound rule.

# ─── Where ElastiCache may place the node (both private subnets) ────────────

resource "aws_elasticache_subnet_group" "cache" {
  name       = "${local.name}-cache"
  subnet_ids = values(aws_subnet.private)[*].id
}

# ─── The cache: one Redis node (dev: no replica, no TLS, no AUTH, no snapshots)

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${local.name}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.cache_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.cache.name
  security_group_ids   = [aws_security_group.cache.id]
  apply_immediately    = true
}