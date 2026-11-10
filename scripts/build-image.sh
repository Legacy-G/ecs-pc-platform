#!/usr/bin/env bash
# Builds the API service container image using buildx with provenance and SBOM
# attestations disabled to generate a standard single OCI manifest instead of an index.
set -euo pipefail

IMAGE_TAG="${1:-$(git rev-parse --short HEAD)}"
APP_VERSION="${APP_VERSION:-0.1.0}"
GIT_SHA="${GIT_SHA:-$(git rev-parse HEAD)}"
AWS_REGION="${AWS_REGION:-eu-north-1}"
if [[ -z "${ECR_REGISTRY:-}" ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || echo "")"
  if [[ -n "${ACCOUNT_ID}" ]]; then
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  else
    ECR_REGISTRY="damolak-api"
  fi
fi
IMAGE_NAME="${ECR_REGISTRY}/damolak-api:${IMAGE_TAG}"

echo "==> Building single-manifest container image: ${IMAGE_NAME} (version=${APP_VERSION}, sha=${GIT_SHA})"

docker buildx build \
  --provenance=false \
  --sbom=false \
  --platform linux/amd64 \
  --build-arg "APP_VERSION=${APP_VERSION}" \
  --build-arg "GIT_SHA=${GIT_SHA}" \
  -t "${IMAGE_NAME}" \
  --load \
  services/api

echo "==> Build complete: ${IMAGE_NAME}"
