#!/usr/bin/env bash
# Generates evidence files for application and infrastructure stacks.
# Embeds current Git commit SHA and UTC timestamp in artifact headers.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
UTC_NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p docs/evidence/application docs/evidence/infrastructure

write_header() {
  local target_file="$1"
  local description="$2"
  cat <<EOF > "$target_file"
# Evidence: ${description}
# Commit: ${GIT_SHA}
# Timestamp (UTC): ${UTC_NOW}

EOF
}

echo "Generating application evidence..."

# 1. pytest unit tests and coverage
write_header docs/evidence/application/pytest.txt "pytest unit tests and coverage enforcement"
pytest -v services/api/tests >> docs/evidence/application/pytest.txt 2>&1 || true

# 2. hadolint Dockerfile linting
write_header docs/evidence/application/hadolint.txt "hadolint Dockerfile static analysis"
if command -v hadolint >/dev/null 2>&1; then
  hadolint services/api/Dockerfile >> docs/evidence/application/hadolint.txt 2>&1 || true
else
  docker run --rm -i "hadolint/hadolint:v2.15.1" < services/api/Dockerfile >> docs/evidence/application/hadolint.txt 2>&1 || true
fi

# 3. Trivy container scan
write_header docs/evidence/application/trivy.txt "trivy container vulnerability and secret scan"
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${ROOT_DIR}:/work:ro" \
  aquasec/trivy:0.76.2 image \
  --ignorefile /work/.trivyignore \
  --ignore-unfixed \
  --severity HIGH,CRITICAL \
  --exit-code 0 \
  "damolak-api:local-dev" >> docs/evidence/application/trivy.txt 2>&1 || true

# 4. Container startup, smoke test, image size, and non-root id
write_header docs/evidence/application/smoke-test.txt "API container startup and smoke test"
docker compose -f docker-compose.yml -f docker-compose.test.yml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d >/dev/null 2>&1
sleep 5
bash scripts/smoke.sh "http://127.0.0.1:8000" "local-dev" >> docs/evidence/application/smoke-test.txt 2>&1 || true

write_header docs/evidence/application/image-size.txt "API container image size"
docker images damolak-api:local-dev --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" >> docs/evidence/application/image-size.txt 2>&1 || true

write_header docs/evidence/application/non-root-check.txt "API container runtime user id"
docker compose -f docker-compose.yml -f docker-compose.test.yml exec -T api id >> docs/evidence/application/non-root-check.txt 2>&1 || true
docker compose -f docker-compose.yml -f docker-compose.test.yml down -v --remove-orphans >/dev/null 2>&1 || true

echo "Generating infrastructure evidence..."

# 5. Bootstrap plan
write_header docs/evidence/infrastructure/bootstrap-plan.txt "Terraform offline plan test for infra/bootstrap"
terraform -chdir=infra/bootstrap test -verbose >> docs/evidence/infrastructure/bootstrap-plan.txt 2>&1 || true

# 6. Shared plan
write_header docs/evidence/infrastructure/shared-plan.txt "Terraform offline plan test for infra/envs/shared"
terraform -chdir=infra/envs/shared test -verbose >> docs/evidence/infrastructure/shared-plan.txt 2>&1 || true

# 7. Dev plan
write_header docs/evidence/infrastructure/dev-plan.txt "Terraform offline plan test for infra/envs/dev"
terraform -chdir=infra/envs/dev test -verbose >> docs/evidence/infrastructure/dev-plan.txt 2>&1 || true
cat <<EOF >> docs/evidence/infrastructure/dev-plan.txt

===============================================================================
Estimated Hourly and Daily Cost of Dev Stack (eu-north-1):
  - Application Load Balancer fixed hourly:       USD 0.02394 / hr (USD 0.575 / day)
  - ALB LCU usage (light test traffic ~0.1 LCU):  USD 0.00076 / hr (USD 0.018 / day)
  - Two ALB public IPv4 addresses (2 AZs):        USD 0.01000 / hr (USD 0.240 / day)
  - ECS Fargate 1 task (0.25 vCPU, 0.5 GB RAM):   USD 0.01358 / hr (USD 0.326 / day)
  - Public IPv4 address on 1 Fargate task ENI:    USD 0.00500 / hr (USD 0.120 / day)
  - NAT Gateway (disabled in dev):                USD 0.00000 / hr (USD 0.000 / day)
  -------------------------------------------------------------------------------
  Total Active Dev Runtime Rate:                  USD 0.05328 - 0.05740 / hr
  Reference Planned Daily Rate:                  ~USD 1.38 / day
===============================================================================
EOF

# Clean up ephemeral .terraform lockfiles and directories
rm -rf infra/modules/*/.terraform infra/envs/*/.terraform infra/bootstrap/.terraform
git checkout -- infra/bootstrap/.terraform.lock.hcl infra/envs/shared/.terraform.lock.hcl infra/envs/dev/.terraform.lock.hcl infra/envs/prod/.terraform.lock.hcl 2>/dev/null || true
rm -f infra/modules/*/.terraform.lock.hcl

echo "Evidence update completed under docs/evidence/."
