#!/usr/bin/env bash
# Read-only AWS inventory and credit check.
# Run after every terraform destroy to verify zero billable resources remain
# in the target region and confirm the Free Plan credit balance.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-damolak}"
export AWS_PAGER=""
export AWS_RETRY_MODE="${AWS_RETRY_MODE:-standard}"
export AWS_MAX_ATTEMPTS="${AWS_MAX_ATTEMPTS:-5}"
REGION="${AWS_REGION:-eu-north-1}"

echo "== Account plan and remaining credits (us-east-1 endpoint) =="
aws freetier get-account-plan-state \
  --region us-east-1 \
  --query '{Plan:accountPlanType,Status:accountPlanStatus,CreditsUSD:accountPlanRemainingCredits.amount,Expires:accountPlanExpirationDate}' \
  --output table

HOURLY_DEV_COST="0.0574"
DAILY_DEV_COST="1.38"
echo "== Expected dev running cost in ${REGION} (1 ALB + 2 ALB public IPs + 1 Fargate task + 1 task public IP) =="
echo "Rate: USD ${HOURLY_DEV_COST}/hr (~USD ${DAILY_DEV_COST}/day). Always destroy with 'make down' when not actively testing."
echo ""
START_DATE="$(date -u +%Y-%m-01)"
END_DATE="$(date -u +%Y-%m-%d)"
if [[ "$START_DATE" == "$END_DATE" ]]; then
  END_DATE="$(date -u -d '+1 day' +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-02)"
fi
aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period "Start=${START_DATE},End=${END_DATE}" \
  --granularity MONTHLY \
  --metrics UnblendedCost BlendedCost \
  --query 'ResultsByTime[].Total' \
  --output json

echo "== Billable resource check in ${REGION} =="
ECS_CLUSTERS="$(aws ecs list-clusters --region "$REGION" --query 'clusterArns' --output text)"
ALB_ARNS="$(aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[].LoadBalancerArn' --output text)"
NAT_GWS="$(aws ec2 describe-nat-gateways --region "$REGION" --filter Name=state,Values=pending,available --query 'NatGateways[].NatGatewayId' --output text)"
EIPS="$(aws ec2 describe-addresses --region "$REGION" --query 'Addresses[].AllocationId' --output text)"
INSTANCES="$(aws ec2 describe-instances --region "$REGION" --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)"
ECR_REPOS="$(aws ecr describe-repositories --region "$REGION" --query 'repositories[].repositoryName' --output text)"
LOG_GROUPS="$(aws logs describe-log-groups --region "$REGION" --query 'logGroups[].logGroupName' --output text)"

printf "ECS clusters   : %s\n" "${ECS_CLUSTERS:-none}"
printf "ALBs           : %s\n" "${ALB_ARNS:-none}"
printf "NAT gateways   : %s\n" "${NAT_GWS:-none}"
printf "ALB public IPs : %s\n" "${EIPS:-none}"
printf "EC2 instances  : %s\n" "${INSTANCES:-none}"
printf "ECR repos      : %s\n" "${ECR_REPOS:-none}"
printf "Log groups     : %s\n" "${LOG_GROUPS:-none}"

if [[ -n "$ECS_CLUSTERS" || -n "$ALB_ARNS" || -n "$NAT_GWS" || -n "$EIPS" || -n "$INSTANCES" ]]; then
  echo "COST_CHECK_WARN: One or more hourly-billed resources are active in ${REGION}." >&2
  exit 1
fi

echo "cost-check: zero hourly-billed compute or network resources active in ${REGION}."
