#!/usr/bin/env bash
# Run one artisan command as a one-off ECS task, using the web service's CURRENT
# task definition (same image + env as the running app), as the web SG.
# Usage:  scripts/artisan-task.sh migrate --force
#         TASK_SG=<sg-id> scripts/artisan-task.sh …     (run as another security group)
# Exit 0 = command succeeded · 1 = command failed · 2 = could not run it.
set -u

(( $# > 0 )) || { echo "usage: $0 <artisan command> [args…]" >&2; exit 2; }
cd "$(dirname "$0")/../infra" || exit 2

out() {
  terraform output -raw "$1" 2>/dev/null || {
    echo "no Terraform output '$1' — is the stack applied?" >&2
    exit 2
  }
}

cluster=$(out ecs_cluster_name) || exit 2
if [[ -n "${TASK_SG:-}" ]]; then
  sg=$TASK_SG
else
  sg=$(out web_security_group_id) || exit 2
fi
subnets=$(terraform output -json private_subnet_ids 2>/dev/null | jq -r 'join(",")')
[[ -n "$subnets" ]] || { echo "no Terraform output 'private_subnet_ids'" >&2; exit 2; }

task_def=$(aws ecs describe-services --cluster "$cluster" --services web \
  --query 'services[0].taskDefinition' --output text) || exit 2
overrides=$(jq -nc '{containerOverrides: [{name: "app", command: (["php", "artisan"] + $ARGS.positional)}]}' --args -- "$@") || {
  echo "failed to build ECS command override" >&2
  exit 2
}

echo "▶ php artisan $*   (task definition ${task_def##*/}, SG $sg)"
task=$(aws ecs run-task --cluster "$cluster" --launch-type FARGATE --task-definition "$task_def" \
  --network-configuration "awsvpcConfiguration={subnets=[$subnets],securityGroups=[$sg],assignPublicIp=DISABLED}" \
  --overrides "$overrides" --started-by artisan-task \
  --query 'tasks[0].taskArn' --output text) || exit 2
[[ "$task" == arn:* ]] || { echo "run-task started nothing: $task" >&2; exit 2; }
id=${task##*/}
echo "  task $id — waiting for it to stop…"
aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task" || exit 2

code=$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task" \
  --query 'tasks[0].containers[?name==`app`].exitCode | [0]' --output text)
reason=$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task" \
  --query 'tasks[0].stoppedReason' --output text)

# A container that never started has no exit code ("None"). Check for a number
# BEFORE any arithmetic: (( None != 0 )) would read None as an unset variable = 0.
if [[ ! "$code" =~ ^[0-9]+$ ]]; then
  echo "✗ the app container never ran: $reason" >&2
  exit 2
fi

read -r log_group prefix < <(aws ecs describe-task-definition --task-definition "$task_def" \
  --query 'taskDefinition.containerDefinitions[?name==`app`].logConfiguration.options | [0].["awslogs-group","awslogs-stream-prefix"]' \
  --output text)
sleep 5
aws logs tail "$log_group" --log-stream-names "$prefix/app/$id" --since 30m --format short

if (( code != 0 )); then
  echo "✗ php artisan $* failed (exit $code)" >&2
  exit 1
fi
echo "✓ php artisan $* succeeded"
exit 0
