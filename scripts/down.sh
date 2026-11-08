#!/usr/bin/env bash
# Teardown Tier 1 (make down): Destroy the dev runtime stack (VPC, ALB, ECS
# service, tasks, CloudWatch alarms/dashboard/logs) so hourly charges drop to
# USD 0.00/hr while preserving shared ECR images and the S3 state bucket.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-damolak}"
export AWS_REGION="${AWS_REGION:-eu-north-1}"

echo "==> Destroying infra/envs/dev stack (profile=${AWS_PROFILE}, region=${AWS_REGION})"
if [[ -f infra/envs/dev/backend.hcl ]]; then
  terraform -chdir=infra/envs/dev init -backend-config=backend.hcl -input=false
else
  terraform -chdir=infra/envs/dev init -input=false
fi

terraform -chdir=infra/envs/dev destroy -input=false

echo "==> Running post-destroy billable resource check"
bash scripts/cost-check.sh
