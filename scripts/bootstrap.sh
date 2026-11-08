#!/usr/bin/env bash
# Provision the S3 remote state bucket (infra/bootstrap) and generate
# gitignored backend.hcl files for shared, dev, and prod stacks.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-damolak}"
export AWS_REGION="${AWS_REGION:-eu-north-1}"

echo "==> Initializing and applying infra/bootstrap (profile=${AWS_PROFILE}, region=${AWS_REGION})"
terraform -chdir=infra/bootstrap init -input=false
terraform -chdir=infra/bootstrap apply -input=false

BUCKET_NAME="$(terraform -chdir=infra/bootstrap output -raw tfstate_bucket_name)"

for env_name in shared dev prod; do
  target_file="infra/envs/${env_name}/backend.hcl"
  cat > "${target_file}" <<EOF
bucket       = "${BUCKET_NAME}"
key          = "${env_name}/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOF
  echo "==> Wrote ${target_file} (gitignored)"
done
