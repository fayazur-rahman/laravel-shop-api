# ─── GitHub Actions → AWS without stored keys (OIDC) ─────────────────────────

# 1. Tell this AWS account to trust tokens signed by GitHub Actions.
#    One per account; every repo's workflows use the same one.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"] # the token's "aud" (audience)
}

# 2. The role a workflow may take on — only from this repo's main branch.
resource "aws_iam_role" "github_actions" {
  name = "laravel-shop-api-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:fayazur-rahman@141312171/laravel-shop-api@1391014470:ref:refs/heads/main"
        }
      }
    }]
  })
}

# 3. What that role may do: push images to our two repositories, nothing else.
resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LogInToTheRegistry"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*" # account-wide by design; can't be scoped to a repository
      },
      {
        Sid    = "PushToOurRepositories"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
        ]
        Resource = [for r in aws_ecr_repository.this : r.arn]
      },
    ]
  })
}