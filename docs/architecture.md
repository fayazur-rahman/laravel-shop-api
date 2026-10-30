# Architecture — laravel-shop-api (dev environment on AWS)

Last verified: YYYY-MM-DD against a fresh `terraform apply` — `scripts/verify-architecture.sh` exit 0.

## 1. At a glance

The Laravel API runs as one ECS Fargate task (Nginx + php-fpm) in private subnets of its own VPC.
The only way in is a public Application Load Balancer on HTTP :80; the task reaches ECR and
CloudWatch Logs through a single NAT gateway. Everything is Terraform in `infra/`; ECR lives in
`infra-shared/` and survives teardown. Dev only: destroyed after every working session.

## 2. Runtime view

```mermaid 
