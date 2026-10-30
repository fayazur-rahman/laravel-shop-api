#!/usr/bin/env bash
# Checks the claims in docs/architecture.md against the live dev stack.
# Exit 0 = every claim matches · 1 = at least one drifted · 2 = could not check.
set -u

cd "$(dirname "$0")/../infra" || exit 2

total=0
drift=0

check() {   # check "<claim>" "<what the doc says>" "<what AWS says>"
  total=$((total + 1))
  if [[ "$3" == "$2" ]]; then
    printf 'OK     %s = %s\n' "$1" "$3"
  else
    printf 'DRIFT  %s: doc says %s, AWS says %s\n' "$1" "$2" "${3:-<nothing>}"
    drift=$((drift + 1))
  fi
}

out() {     # out <name> → the value of a Terraform output; exit 2 if there is none
  terraform output -raw "$1" 2>/dev/null || {
    echo "no Terraform output '$1' — is the stack applied?" >&2
    exit 2
  }
}

vpc=$(out vpc_id) || exit 2
tg=$(out web_target_group_arn)      || exit 2
alb_dns=$(out alb_dns_name)         || exit 2
web_sg=$(out web_security_group_id) || exit 2
alb_sg=$(out alb_security_group_id) || exit 2
cluster=$(out ecs_cluster_name)     || exit 2

# ── Network ──────────────────────────────────────────────────────────────────
check "VPC CIDR" "10.20.0.0/16" \
  "$(aws ec2 describe-vpcs --vpc-ids "$vpc" --query 'Vpcs[0].CidrBlock' --output text)"
check "Subnets in the VPC" "4" \
  "$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query 'length(Subnets)' --output text)"
check "NAT gateways" "1" \
  "$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc" "Name=state,Values=available" \
       --query 'length(NatGateways)' --output text)"
nat_subnet=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc" "Name=state,Values=available" \
  --query 'NatGateways[0].SubnetId' --output text)
check "NAT gateway's subnet" "10.20.0.0/24" \
  "$(aws ec2 describe-subnets --subnet-ids "$nat_subnet" --query 'Subnets[0].CidrBlock' --output text)"

# ── Load balancer ────────────────────────────────────────────────────────────
alb_arn=$(aws elbv2 describe-target-groups --target-group-arns "$tg" \
  --query 'TargetGroups[0].LoadBalancerArns[0]' --output text)
check "ALB scheme" "internet-facing" \
  "$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" --query 'LoadBalancers[0].Scheme' --output text)"
check "ALB availability zones" "2" \
  "$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" \
       --query 'length(LoadBalancers[0].AvailabilityZones)' --output text)"
check "Listener" "80 HTTP" \
  "$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[0].[Port,Protocol]' --output text | tr '\t' ' ')"
check "Health check path" "/up" \
  "$(aws elbv2 describe-target-groups --target-group-arns "$tg" --query 'TargetGroups[0].HealthCheckPath' --output text)"

# ── Firewall chain ───────────────────────────────────────────────────────────
check "Web SG inbound rules" "1" \
  "$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$web_sg" \
       --query 'length(SecurityGroupRules[?!IsEgress])' --output text)"
check "Web SG inbound source" "$alb_sg" \
  "$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$web_sg" \
       --query 'SecurityGroupRules[?!IsEgress] | [0].ReferencedGroupInfo.GroupId' --output text)"

# ── Compute ──────────────────────────────────────────────────────────────────
check "Web tasks desired" "1" \
  "$(aws ecs describe-services --cluster "$cluster" --services web --query 'services[0].desiredCount' --output text)"
check "Task public IP" "DISABLED" \
  "$(aws ecs describe-services --cluster "$cluster" --services web \
       --query 'services[0].networkConfiguration.awsvpcConfiguration.assignPublicIp' --output text)"
td=$(aws ecs describe-services --cluster "$cluster" --services web --query 'services[0].taskDefinition' --output text)
check "Task containers" "app,web" \
  "$(aws ecs describe-task-definition --task-definition "$td" \
       --query 'join(`","`, sort(taskDefinition.containerDefinitions[].name))' --output text)"
check "Task size (CPU units, MiB)" "512 1024" \
  "$(aws ecs describe-task-definition --task-definition "$td" --query 'taskDefinition.[cpu,memory]' --output text | tr '\t' ' ')"
log_group=$(aws ecs describe-task-definition --task-definition "$td" \
  --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-group"' --output text)
check "Log retention (days)" "7" \
  "$(aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].retentionInDays' --output text)"

# ── End to end ───────────────────────────────────────────────────────────────
check "Healthy targets" "1" \
  "$(aws elbv2 describe-target-health --target-group-arn "$tg" \
       --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)"
check "/up through the ALB" "200" \
  "$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "http://$alb_dns/up")"

if (( drift > 0 )); then
  echo "$drift of $total claims drifted — fix the doc or the infra, then re-run."
  exit 1
fi
echo "All $total claims match."
exit 0

