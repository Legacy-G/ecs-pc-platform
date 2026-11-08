#!/usr/bin/env bash
# Teardown Tier 2 (make nuke): Destroy all environments (dev, shared, SSM
# parameters, and bootstrap S3 state bucket) after explicit confirmation.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-damolak}"
export AWS_REGION="${AWS_REGION:-eu-north-1}"
PROJECT_NAME="${PROJECT_NAME:-damolak}"

read -r -p "Type 'NUKE' to permanently destroy dev, shared, SSM parameters, and bootstrap state: " confirm
if [[ "${confirm}" != "NUKE" ]]; then
  echo "Aborted."
  exit 1
fi

echo "==> 1/4 Destroying infra/envs/dev"
if [[ -d infra/envs/dev/.terraform ]]; then
  terraform -chdir=infra/envs/dev destroy -auto-approve -input=false
fi

echo "==> 2/4 Deleting SSM SecureString parameter /${PROJECT_NAME}/dev/api-key (if present)"
aws ssm delete-parameter \
  --region "${AWS_REGION}" \
  --name "/${PROJECT_NAME}/dev/api-key" >/dev/null 2>&1 || true

echo "==> 3/4 Destroying infra/envs/shared (ECR, IAM CI user, AWS Budget)"
if [[ -d infra/envs/shared/.terraform ]]; then
  terraform -chdir=infra/envs/shared destroy -auto-approve -input=false
fi

echo "==> 4/4 Emptying and destroying infra/bootstrap S3 state bucket"
if [[ -d infra/bootstrap/.terraform ]]; then
  BUCKET_NAME="$(terraform -chdir=infra/bootstrap output -raw tfstate_bucket_name 2>/dev/null || true)"
  if [[ -n "${BUCKET_NAME}" ]]; then
    versions_json="$(aws s3api list-object-versions --bucket "${BUCKET_NAME}" --output json 2>/dev/null || true)"
    if [[ -n "${versions_json}" ]]; then
      python -c '
import json, subprocess, sys
data = json.loads(sys.stdin.read() or "{}")
objs = [{"Key": x["Key"], "VersionId": x["VersionId"]} for k in ("Versions", "DeleteMarkers") for x in data.get(k, [])]
if objs:
    subprocess.run(["aws", "s3api", "delete-objects", "--bucket", sys.argv[1], "--delete", json.dumps({"Objects": objs})], check=True)
' "${BUCKET_NAME}" <<< "${versions_json}" >/dev/null
    fi
  fi
  terraform -chdir=infra/bootstrap destroy -auto-approve -input=false
fi

rm -f infra/envs/shared/backend.hcl infra/envs/dev/backend.hcl infra/envs/prod/backend.hcl

echo "==> Running post-nuke billable resource check"
bash scripts/cost-check.sh
