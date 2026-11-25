#!/usr/bin/env bash
# teardown.sh — destroy one environment, then prove nothing that bills is left.
#
#   scripts/teardown.sh dev        terraform destroy the dev stack, then scan the account
#   scripts/teardown.sh staging    the same for staging (workspace staging)
#   scripts/teardown.sh --check    scan only; destroys nothing
#
# Exit: 0 = nothing left · 1 = something is still there (lines marked !!) · 2 = couldn't run
# The scan asks AWS, not Terraform: things made by hand, a half-finished destroy,
# or the other environment show up too. It covers the current region only.

LEFT=0     # kinds of resource still there
ERRORS=0   # checks that couldn't run

# check "<label>" <aws command …>  → one line of output, and the counters updated.
# Call it directly, never as $(check …): a $(…) subshell would lose LEFT and ERRORS (bug class #1).
check() {
  local label=$1 found
  shift
  if ! found=$("$@" 2>&1); then
    echo "  ??  $label: the check failed: ${found:0:120}"
    ERRORS=$((ERRORS + 1))
  elif [[ -z "$found" || "$found" == "None" ]]; then
    echo "  ok  $label"
  else
    echo "  !!  $label: ${found//[$'\t\n']/ }"
    LEFT=$((LEFT + 1))
  fi
}

scan() {
  echo "What's still there in $(aws configure get region):"
  check "NAT gateways"         aws ec2 describe-nat-gateways --filter Name=state,Values=pending,available --query 'NatGateways[].NatGatewayId' --output text
  check "Elastic IPs"          aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text
  check "Load balancers"       aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text
  check "ECS clusters"         aws ecs list-clusters --query 'clusterArns[]' --output text
  check "RDS databases"        aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text
  check "RDS manual snapshots" aws rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[].DBSnapshotIdentifier' --output text
  check "ElastiCache clusters" aws elasticache describe-cache-clusters --query 'CacheClusters[].CacheClusterId' --output text
  check "EC2 instances"        aws ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text
  check "Non-default VPCs"     aws ec2 describe-vpcs --filters Name=is-default,Values=false --query 'Vpcs[].VpcId' --output text
  check "Our alarms"           aws cloudwatch describe-alarms --alarm-name-prefix laravel-shop-api --query 'MetricAlarms[].AlarmName' --output text
}

case "${1:-}" in
  --check)
    ;;
  dev | staging)
    ENV=$1
    WS=$ENV
    [[ "$ENV" == dev ]] && WS=default
    cd "$(dirname "$0")/../infra" || exit 2
    [[ -f "$ENV.tfvars" ]] || { echo "no infra/$ENV.tfvars here" >&2; exit 2; }
    terraform workspace select "$WS" >/dev/null || exit 2
    echo "Destroying $ENV (workspace $WS). Terraform asks you to type yes."
    terraform destroy -var-file="$ENV.tfvars"
    rc=$?
    echo "terraform destroy exit $rc · resources left in $ENV's state: $(terraform state list | wc -l)"
    terraform workspace select default >/dev/null
    ;;
  *)
    echo "usage: $0 dev | staging | --check" >&2
    exit 2
    ;;
esac

scan
if (( LEFT > 0 )); then
  echo "Result: $LEFT kind(s) of resource still there. Not torn down."
  exit 1
elif (( ERRORS > 0 )); then
  echo "Result: $ERRORS check(s) couldn't run. Can't say it's clean."
  exit 2
fi
echo "Result: nothing left."
exit 0