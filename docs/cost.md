# Cost

What this stack costs, how to turn it off, and what would make it cheaper.
Prices: us-east-1 list prices, checked on the AWS pricing pages on 2026-11-23. One month = 730 hours.

## Dev stack, per piece

| Piece | Price | Per hour | Per month if left on |
|---|---|---|---|
| NAT gateway + its Elastic IP | $0.045/h + $0.005/h (+ $0.045 per GB) | $0.050 | $36.50 |
| Load balancer + 2 public IPv4 | $0.0225/h + 2 × $0.005/h (+ LCUs) | $0.0325 | $23.73 |
| Fargate web task (0.5 vCPU, 1 GB) | $0.04048 per vCPU-h, $0.004445 per GB-h | $0.0247 | $18.02 |
| Fargate worker task (0.25 vCPU, 0.5 GB) | same | $0.0123 | $9.01 |
| RDS MySQL db.t4g.micro, 20 GB gp3 | $0.016/h + $0.115 per GB-month | $0.016 | $13.98 |
| ElastiCache Redis OSS cache.t4g.micro | $0.016/h | $0.016 | $11.68 |
| DB secret, 3 alarms, 1 dashboard, logs, S3 | $0.40/month secret; rest in free allowances | — | ≈ $0.40 |
| **Total** | | **≈ $0.155** | **≈ $113** |

The NAT gateway is the biggest line, although it carries almost no traffic in dev.
NAT gateway, load balancer and ElastiCache bill a started hour as a full hour; Fargate bills per second, RDS per second with a 10-minute minimum.

## What it really costs

- **Per session:** 1.5 hours up, then destroyed ≈ $0.27.
- **Per month at 2 hours a day:** ≈ $9–10.
- **Always on (infra-shared + state):** 2 app-key secrets $0.80, ECR images <GB> GB × $0.10, state bucket < $0.01, SNS topic, OIDC provider and IAM roles free → about $1 a month.
- **Staging** is the same stack again, only while it's up.
- **Budget:** <limit> USD a month, emails on overspend.
- The account is on the AWS Free plan: credits pay the bill for now.

## Turning it off and on

- Off: `scripts/teardown.sh dev` (or `staging`). Runs `terraform destroy`, then asks AWS for NAT gateways, Elastic IPs, load balancers, ECS clusters, RDS instances and manual snapshots, ElastiCache clusters, EC2 instances, non-default VPCs and this project's alarms. Exit 0 = nothing left, 1 = something still there, 2 = couldn't run.
- Check only: `scripts/teardown.sh --check`.
- On: `terraform apply -var-file=dev.tfvars` in `infra/`, then the release step (`scripts/artisan-task.sh migrate --force`, `db:seed --force`). From a fresh clone: <N> minutes to a working app (checked 2026-11-23).
- The scan covers us-east-1 only, and doesn't list what infra-shared keeps on purpose (ECR, secrets, SNS).

## Cheaper options (not built)

| Option | Monthly effect if left on | Trade-off |
|---|---|---|
| Tasks in public subnets, no NAT gateway | ≈ −$29 (−$36.50 NAT, +$7.30 task IPs) | Tasks get public IPs; only the security group keeps them closed |
| VPC endpoints instead of the NAT | ≈ +$58 for 4 endpoints in 2 AZs | Costs more at this size; pays off with heavy NAT traffic |
| Fargate Spot for the worker | ≈ −$6 | Can be stopped with 2 minutes' notice; fine for a worker (jobs retry), not for web |
| Fargate on ARM (Graviton) | ≈ −$5.40 | CI must build arm64 images |
| Valkey instead of Redis OSS | −$2.34 | Different engine and resource; new cluster |
| One EC2 instance with Docker Compose | whole stack ≈ $15–20 | No managed DB backups, no self-healing, no load balancer, no scaling |

## Production would cost more

One NAT gateway per AZ (+$36.50), Multi-AZ RDS (+$11.68), at least 2 web tasks (+$18.02): about $180 a month before traffic-based charges.

