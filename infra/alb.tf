# ─── Firewall for the load balancer ─────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Public ALB for the Laravel web tasks"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere (public front door)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Only to the web tasks, port 80"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# ─── The load balancer: one node per public subnet ──────────────────────────

resource "aws_lb" "web" {
  name               = local.name # laravel-shop-api-dev (limit: 32 characters)
  load_balancer_type = "application"
  internal           = false
  subnets            = values(aws_subnet.public)[*].id
  security_groups    = [aws_security_group.alb.id]

  # Reject requests with malformed headers instead of passing them to Nginx.
  drop_invalid_header_fields = true
}

# ─── Target group: the list of task IPs + how to check them ─────────────────

resource "aws_lb_target_group" "web" {
  name                 = "${local.name}-web" # 24 characters, limit 32
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip" # Fargate tasks are IPs, not instances
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30 # default 300 s

  health_check {
    path                = "/up" # shallow: can THIS task serve? (not /health)
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ─── Listener: port 80 → target group ───────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
