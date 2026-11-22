# ─── Laravel's APP_KEY, one secret per environment ───────────────────────────
# Long-lived like the ECR repos: the key must survive infra/ teardowns.
# Terraform creates the empty secret; the value is put with the AWS CLI,
# so it never appears in Git or in Terraform state.

resource "aws_secretsmanager_secret" "app_key" {
  for_each = toset(["dev", "staging"])

  name        = "laravel-shop-api/${each.key}/app-key"
  description = "Laravel APP_KEY for the ${each.key} environment"
}