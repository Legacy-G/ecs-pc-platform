#!/usr/bin/env bash
# Generates a cryptographically secure random API key and writes it directly to
# AWS SSM Parameter Store as a SecureString without printing or echoing the value.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-damolak}"
export AWS_REGION="${AWS_REGION:-eu-north-1}"
export AWS_PAGER=""

ENV_NAME="${1:-dev}"
ROTATE_FLAG="${2:-}"

PARAM_NAME="/damolak/${ENV_NAME}/api-key"

echo "==> Configuring SSM Parameter Store secret for ${ENV_NAME} (profile=${AWS_PROFILE}, region=${AWS_REGION})"

# Check if parameter already exists
PARAM_EXISTS=false
if aws ssm get-parameter --name "${PARAM_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  PARAM_EXISTS=true
fi

if [[ "${PARAM_EXISTS}" == "true" && "${ROTATE_FLAG}" != "--rotate" ]]; then
  echo "ERROR: Parameter ${PARAM_NAME} already exists. Pass --rotate to overwrite." >&2
  exit 1
fi

TMP_KEY_FILE="$(mktemp "${TMPDIR:-/tmp}/api-key.XXXXXX")"
chmod 600 "${TMP_KEY_FILE}"

cleanup() {
  if [[ -f "${TMP_KEY_FILE}" ]]; then
    rm -f "${TMP_KEY_FILE}"
  fi
}
trap cleanup EXIT

# Generate with openssl rand or python secrets
if command -v openssl >/dev/null 2>&1; then
  openssl rand -hex 32 | tr -d '\r\n' > "${TMP_KEY_FILE}"
else
  python -c "import secrets; print(secrets.token_hex(32), end='')" > "${TMP_KEY_FILE}"
fi

OVERWRITE_OPT=""
if [[ "${PARAM_EXISTS}" == "true" && "${ROTATE_FLAG}" == "--rotate" ]]; then
  OVERWRITE_OPT="--overwrite"
fi

aws ssm put-parameter \
  --name "${PARAM_NAME}" \
  --description "API key secret for ${ENV_NAME} environment" \
  --type "SecureString" \
  --value "file://${TMP_KEY_FILE}" \
  --region "${AWS_REGION}" \
  ${OVERWRITE_OPT} >/dev/null

echo "==> Secret successfully written to ${PARAM_NAME}."
echo "==> Verification (metadata only, without decryption):"
aws ssm describe-parameters \
  --filters "Key=Name,Values=${PARAM_NAME}" \
  --region "${AWS_REGION}" \
  --query "Parameters[0].{Name:Name,Type:Type,Version:Version,LastModifiedDate:LastModifiedDate}" \
  --output table
