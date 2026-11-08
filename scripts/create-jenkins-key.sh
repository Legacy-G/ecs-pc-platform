#!/usr/bin/env bash
# Out-of-band CLI script to create or rotate the access key for the
# damolak-jenkins-ci IAM user so the secret key never enters Terraform state.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-damolak}"
IAM_USER_NAME="${1:-damolak-jenkins-ci}"
OUTPUT_FILE="${2:-jenkins-ci-access-key.json}"

umask 077
echo "==> Creating access key for IAM user ${IAM_USER_NAME} (profile=${AWS_PROFILE})"
aws iam create-access-key \
  --user-name "${IAM_USER_NAME}" \
  --output json > "${OUTPUT_FILE}"

echo "==> Wrote credentials to ${OUTPUT_FILE} (mode 0600, gitignored)."
echo "==> Load into local Jenkins credentials store, then shred/remove ${OUTPUT_FILE}."
