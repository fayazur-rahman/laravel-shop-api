# ─── Secrets: referenced by ARN, read by ECS when a task starts ──────────────

# The app key's secret lives in ../infra-shared (it survives teardown).
data "aws_secretsmanager_secret" "app_key" {
  name = "laravel-shop-api/${var.environment}/app-key"
}

locals {
  # Shared by the app container and the worker, like local.app_environment.
  app_secrets = [
    { name = "APP_KEY", valueFrom = data.aws_secretsmanager_secret.app_key.arn },
    # RDS's secret is JSON {"username": …, "password": …}: ":password::" picks one key.
    { name = "DB_PASSWORD", valueFrom = "${aws_db_instance.mysql.master_user_secret[0].secret_arn}:password::" },
  ]
}

# The execution role (ECS itself) fetches the values before the containers start.
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "read-app-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        data.aws_secretsmanager_secret.app_key.arn,
        aws_db_instance.mysql.master_user_secret[0].secret_arn,
      ]
    }]
  })
}
