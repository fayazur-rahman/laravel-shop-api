# ─── Monitoring: three alarms that email you, one dashboard ──────────────────

# The topic lives in ../infra-shared (its email subscription is confirmed once).
data "aws_sns_topic" "alerts" {
  name = "laravel-shop-api-alerts"
}

# 1. Users are getting errors: the app answered 5xx at least 5 times in one minute.
resource "aws_cloudwatch_metric_alarm" "web_5xx" {
  alarm_name          = "${local.name}-web-5xx"
  alarm_description   = "The app returned 5 or more 5xx responses in one minute."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.web.arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching" # a minute with no requests is a minute with no errors
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  ok_actions          = [data.aws_sns_topic.alerts.arn]
}

# 2. The web tasks are running hot: average CPU above 80% for 3 minutes in a row.
resource "aws_cloudwatch_metric_alarm" "web_cpu" {
  alarm_name          = "${local.name}-web-cpu"
  alarm_description   = "Web service CPU above 80% for 3 minutes."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = aws_ecs_cluster.main.name, ServiceName = aws_ecs_service.web.name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  ok_actions          = [data.aws_sns_topic.alerts.arn]
}

# 3. The database is filling up with connections (a micro instance allows only a few dozen).
resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "${local.name}-db-connections"
  alarm_description   = "More than 40 database connections for 5 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mysql.identifier }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 40
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  ok_actions          = [data.aws_sns_topic.alerts.arn]
}

# One page with every tier on it.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "alarm", x = 0, y = 0, width = 24, height = 2
        properties = {
          title = "Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.web_5xx.arn,
            aws_cloudwatch_metric_alarm.web_cpu.arn,
            aws_cloudwatch_metric_alarm.db_connections.arn,
          ]
        }
      },
      {
        type = "metric", x = 0, y = 2, width = 12, height = 6
        properties = {
          title = "ALB: requests and 5xx per minute", region = var.region, view = "timeSeries", stat = "Sum", period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.web.arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 2, width = 12, height = 6
        properties = {
          title = "ALB: response time p95 (seconds)", region = var.region, view = "timeSeries", stat = "p95", period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.web.arn_suffix],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 8, width = 8, height = 6
        properties = {
          title = "ECS: CPU % (web, worker)", region = var.region, view = "timeSeries", stat = "Average", period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.web.name],
            [".", ".", ".", ".", ".", aws_ecs_service.worker.name],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 8, width = 8, height = 6
        properties = {
          title = "RDS: CPU % and connections", region = var.region, view = "timeSeries", stat = "Maximum", period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.mysql.identifier],
            [".", "DatabaseConnections", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 8, width = 8, height = 6
        properties = {
          title = "Redis: CPU % and connections", region = var.region, view = "timeSeries", stat = "Maximum", period = 60
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_cluster.redis.cluster_id, "CacheNodeId", "0001"],
            [".", "CurrConnections", ".", ".", ".", "."],
          ]
        }
      },
      {
        type = "log", x = 0, y = 14, width = 24, height = 6
        properties = {
          title  = "Latest errors (Laravel, Nginx and worker logs)"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.web.name}' | SOURCE '${aws_cloudwatch_log_group.worker.name}' | fields @timestamp, @logStream, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
        }
      },
    ]
  })
}
