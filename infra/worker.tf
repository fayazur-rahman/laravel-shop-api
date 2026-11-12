# ─── Firewall for the worker tasks: no inbound, all outbound ─────────────────

resource "aws_security_group" "worker" {
  name        = "${local.name}-worker"
  description = "Laravel queue workers: no inbound, outbound to Redis/MySQL/ECR/logs"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "worker_all" {
  security_group_id = aws_security_group.worker.id
  description       = "All outbound (ECR pulls, logs, MySQL, Redis)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# The data stores admit the worker too (one rule each, next to the web rules).

resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_worker" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from the queue workers"
  referenced_security_group_id = aws_security_group.worker.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_vpc_security_group_ingress_rule" "cache_redis_from_worker" {
  security_group_id            = aws_security_group.cache.id
  description                  = "Redis from the queue workers"
  referenced_security_group_id = aws_security_group.worker.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

# ─── Logs: separate group, so worker lines don't mix with web lines ──────────

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${local.name}/worker"
  retention_in_days = 7
}

# ─── Task definition: one container, the app image, a different command ─────

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # 0.25 vCPU: one job at a time is light work
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      command   = ["php", "artisan", "queue:work", "redis", "--tries=3", "--timeout=60"]
      environment = concat(local.app_environment, [
        { name = "MAIL_MAILER", value = var.worker_mail_mailer }, # log = write mails to the log
      ])
      stopTimeout = 90 # > --timeout, so SIGTERM lets the running job finish
      logConfiguration = {
        logDriver = "awslogs"
        options = merge(local.log_options, {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-stream-prefix" = "worker"
        })
      }
    },
  ])
}

# ─── Service: keep N workers running; no load balancer ────────────────────────

resource "aws_ecs_service" "worker" {
  name            = "worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.worker.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_route_table_association.private,
    aws_iam_role_policy_attachment.task_execution,
  ]
}