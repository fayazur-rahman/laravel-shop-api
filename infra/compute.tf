# ─── Images (repos live in ../infra-shared, they survive destroy) ───────────


data "aws_ecr_repository" "app" {
  name = "laravel-shop-api-app"
}


data "aws_ecr_repository" "web" {
  name = "laravel-shop-api-web"
}


# ─── Logs ───────────────────────────────────────────────────────────────────


resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.name}/web"
  retention_in_days = 7
}


# ─── The role ECS itself uses to start the task (pull images, write logs) ──


resource "aws_iam_role" "task_execution" {
  name = "${local.name}-task-execution"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ─── Cluster ────────────────────────────────────────────────────────────────


resource "aws_ecs_cluster" "main" {
  name = local.name
}


# ─── Firewall for the web tasks ─────────────────────────────────────────────


resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "Laravel web tasks (nginx + php-fpm)"
  vpc_id      = aws_vpc.main.id
}


resource "aws_vpc_security_group_ingress_rule" "web_http_from_vpc" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from inside the VPC only"
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}


resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound (ECR pulls, logs, later DB/Redis)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ─── Task definition: two containers, one task ──────────────────────────────


locals {
  log_options = {
    "awslogs-group"         = aws_cloudwatch_log_group.web.name
    "awslogs-region"        = var.region
    "awslogs-stream-prefix" = "web"
  }
}


resource "aws_ecs_task_definition" "web" {
  family                   = "${local.name}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512  # 0.5 vCPU, shared by both containers
  memory                   = 1024 # 1 GB
  execution_role_arn       = aws_iam_role.task_execution.arn


  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }


  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      environment = [
        { name = "APP_NAME", value = "laravel-shop-api" },
        { name = "APP_ENV", value = var.environment },
        { name = "APP_DEBUG", value = "false" },
        { name = "APP_KEY", value = var.app_key },
        { name = "LOG_CHANNEL", value = "stderr" },
        { name = "LOG_LEVEL", value = "info" },
      ]
      logConfiguration = { logDriver = "awslogs", options = local.log_options }
    },
    {
      name         = "web"
      image        = "${data.aws_ecr_repository.web.repository_url}:${var.image_tag}"
      essential    = true
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      environment = [
        # Same task = same network namespace: php-fpm is on localhost, not "app".
        { name = "PHP_FPM_HOST", value = "127.0.0.1" },
      ]
      dependsOn = [{ containerName = "app", condition = "START" }]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://127.0.0.1/up > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
      logConfiguration = { logDriver = "awslogs", options = local.log_options }
    },
  ])
}


# ─── Service: "keep 1 copy of this task running, in the private subnets" ────


resource "aws_ecs_service" "web" {
  name            = "web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "FARGATE"


  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = false
  }


  # A new task can't pull images until the private route to the NAT exists.
  depends_on = [aws_route_table_association.private, aws_iam_role_policy_attachment.task_execution]
}
