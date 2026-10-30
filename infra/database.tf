# ─── Firewall: MySQL only from the web tasks ────────────────────────────────

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "RDS MySQL - only the web tasks may connect"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_web" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL only from the web tasks"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

# No egress rule on purpose: the database only answers connections, and
# security groups are stateful, so replies leave without an outbound rule.

# ─── Where RDS may place the database (both private subnets, 2 AZs) ─────────

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db"
  subnet_ids = values(aws_subnet.private)[*].id
}

# ─── MySQL server settings ──────────────────────────────────────────────────

resource "aws_db_parameter_group" "mysql" {
  name   = "${local.name}-mysql84"
  family = "mysql8.4"

  parameter {
    name  = "slow_query_log" # dynamic: applies to the running server
    value = "1"
  }

  parameter {
    name  = "long_query_time" # seconds; queries slower than this are logged
    value = "1"
  }
}

# ─── The database ───────────────────────────────────────────────────────────

resource "aws_db_instance" "mysql" {
  identifier     = "${local.name}-mysql"
  engine         = "mysql"
  engine_version = "8.4" # RDS picks the current 8.4.x patch
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name             = "shop"
  username            = "shop"
  password_wo         = var.db_password # write-only: never stored in state
  password_wo_version = 1               # bump to send a new password
  port                = 3306

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name
  publicly_accessible    = false
  multi_az               = false # dev: one AZ (cost)

  backup_retention_period = 1
  skip_final_snapshot     = true  # dev only: destroy deletes the data
  deletion_protection     = false # dev only
  apply_immediately       = true  # dev only: don't wait for the maintenance window
}