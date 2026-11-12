# ECS Platform Challenge

[![CI](https://github.com/Legacy-G/ecs-pc-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/Legacy-G/ecs-pc-platform/actions/workflows/ci.yml)

FastAPI service on AWS ECS Fargate behind an Application Load Balancer, provisioned with Terraform and deployed by Jenkins.

---

## Architecture Overview

The platform provisions an isolated, multi-AZ network architecture hosting containerized workloads on AWS ECS Fargate:

- **Compute:** AWS ECS Fargate running Linux AMD64 containers with read-only root filesystems, tmpfs mounted at `/tmp`, and execution constrained to unprivileged user `appuser` (UID 10001).
- **Networking:** Custom VPC (`10.20.0.0/16`) spanning two Availability Zones (`eu-north-1a`, `eu-north-1b`) with public subnets for external load balancing and direct egress.
- **Traffic Routing:** Application Load Balancer with independent HTTP target group, active health checks, and a default 404 listener for unrouted requests.
- **Secrets Management:** Sensitive API keys stored in AWS Systems Manager (SSM) Parameter Store as `SecureString` parameters and injected into memory at runtime without entering Terraform state.
- **Observability:** Centralized CloudWatch log group (`/ecs/damolak-dev`), structured JSON logging, 5 CloudWatch metric alarms, and an Amazon SNS topic for automated operator alerts.

![AWS Architecture](docs/architecture/aws-architecture.png)

---

## Repository Map

```text
.
├── .github/
│   ├── dependabot.yml            # Weekly dependency updates (Docker, Pip, Terraform, Actions)
│   └── workflows/ci.yml          # Credential-free GitHub Actions verification pipeline
├── ci/
│   ├── jenkins/                  # Pinned LTS Jenkins controller with JCasC and plugins
│   │   ├── Dockerfile            # Jenkins controller image with CLI tooling
│   │   ├── docker-compose.yml    # Controller daemon bound to 127.0.0.1:8088
│   │   ├── jenkins.yaml          # Jenkins Configuration as Code definition
│   │   └── plugins.txt           # Explicitly pinned Jenkins plugins
│   └── versions.env              # Pinned tool, base image, and provider versions
├── docs/
│   ├── adr/                      # Architecture Decision Records (0001 - 0007)
│   ├── architecture/             # Diagrams as code (Python generator, SVG, PNG)
│   ├── evidence/                 # Sanitized validation evidence
│   ├── manual-setup.md           # Operator procedures requiring personal credentials
│   ├── REQUIREMENTS.md           # Traceability matrix mapping requirements to evidence
│   └── RUNBOOK.md                # Operations, monitoring, recovery drills, and teardown
├── infra/
│   ├── bootstrap/                # S3 state bucket with native lockfile locking
│   ├── envs/
│   │   ├── dev/                  # Development stack (VPC, ALB, ECS, Observability)
│   │   ├── prod/                 # Production stack (Plan-only target)
│   │   └── shared/               # Shared resources (ECR, Budgets, CI IAM User)
│   └── modules/                  # Reusable Terraform modules (alb, ecs-service, network, etc.)
├── scripts/                      # Operational scripts (bootstrap, cost check, smoke tests)
├── services/
│   └── api/                      # FastAPI application with tests and Dockerfile
├── docker-compose.yml            # Local development orchestration
├── Jenkinsfile                   # Declarative pipeline for automated cloud deployments
└── Makefile                      # Standard operator targets and lifecycle commands
```

---

## Prerequisites

- **Docker Desktop** (or Docker Engine with Compose)
- **Terraform** >= 1.17.0, < 2.0.0
- **AWS CLI v2** configured with `damolak` profile in `eu-north-1`
- **Python** >= 3.13, < 3.14 with `pip`
- **GitHub CLI** (`gh`)

---

## Deployment Steps

Follow these steps to replicate the environment from scratch.

### 1. Bootstrap State Backend

Generate the local backend configuration and initialize S3 state storage:

```bash
make bootstrap
```

This provisions `damolak-tfstate-<ACCOUNT_ID>-eu-north-1` with S3 native lockfile locking, encryption, and versioning.

### 2. Deploy Shared Platform Stack

Provision the shared Amazon ECR repository, AWS Budgets guardrail, and Jenkins CI IAM credentials:

```bash
terraform -chdir=infra/envs/shared init -backend-config=backend.hcl
terraform -chdir=infra/envs/shared apply -auto-approve
```

### 3. Generate Secret API Key in SSM

Create the `SecureString` secret parameter in SSM Parameter Store without exposing the secret to Terraform:

```bash
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/create-api-key.sh dev
```

### 4. Build and Push Initial Image

Build the container image with provenance disabled and push to Amazon ECR:

```bash
GIT_SHA=$(git rev-parse --short HEAD)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.eu-north-1.amazonaws.com"

aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin "${REGISTRY}"
docker buildx build --platform linux/amd64 --provenance=false --sbom=false --load -t "damolak-api:${GIT_SHA}" -f services/api/Dockerfile services/api
docker tag "damolak-api:${GIT_SHA}" "${REGISTRY}/damolak-api:${GIT_SHA}"
docker push "${REGISTRY}/damolak-api:${GIT_SHA}"
```

### 5. Deploy Development Application Stack

Deploy the networking, load balancer, CloudWatch alarms, and ECS Fargate service:

```bash
terraform -chdir=infra/envs/dev init -backend-config=backend.hcl
terraform -chdir=infra/envs/dev apply -var="image_tag=${GIT_SHA}" -var="git_sha=${GIT_SHA}" -var="app_version=0.1.1" -auto-approve
```

### 6. Verify Deployment

Execute the end-to-end smoke test against the live Application Load Balancer:

```bash
ALB_URL=$(terraform -chdir=infra/envs/dev output -raw service_url)
bash scripts/smoke.sh "${ALB_URL}" "${GIT_SHA}" "/damolak/dev/api-key"
```

---

## CI/CD Architecture & Pipeline Flow

The deployment lifecycle uses a two-tier approach separating pull-request quality gates from deployment execution:

1. **GitHub Actions (CI Only):** Runs offline linting (`check-hygiene`, `ruff`), security scanning (`gitleaks`, `hadolint`, `trivy`), unit tests (`pytest`), and Terraform format/validation. It contains zero AWS credentials and cannot write to cloud infrastructure.
2. **Jenkins Controller (CD & Deployment):** Runs as a local Docker container (`127.0.0.1:8088`) executing declarative builds on changes merged to `main`. It authenticates to AWS via a dedicated IAM user (`damolak-jenkins-ci`) restricted by an explicit Permissions Boundary.

![CI/CD Flow](docs/architecture/cicd-flow.png)

### Why GitHub Actions Does Not Deploy (SCP Restriction)
The AWS account sits within an AWS Organization whose Service Control Policy (SCP) explicitly denies `iam:CreateOpenIDConnectProvider`. Because GitHub Actions cannot assume IAM roles via OIDC and long-lived cloud credentials must not be stored in third-party services, all cloud deployments are executed by the local Jenkins controller. See [ADR 0007](docs/adr/0007-github-actions-ci-only-scp-oidc-block.md) for full architectural context.

---

## Monitoring, Logs & Alarms

- **Structured Logs:** Containers emit JSON logs to stdout. View live logs with AWS CLI:
  ```bash
  aws logs tail /ecs/damolak-dev --region eu-north-1 --follow
  ```
- **Operational Dashboard:** Inspect metrics on the CloudWatch dashboard `damolak-dev-overview`.
- **Active Alarms:** Five CloudWatch alarms monitor the service:
  1. `damolak-dev-alb-5xx`: Fires when ALB target 5xx response count exceeds 5 in 1 minute (`threshold = 5`, `period = 60`, `evaluation_periods = 1`, `Sum`).
  2. `damolak-dev-unhealthy-hosts`: Fires when Target Group `UnHealthyHostCount` exceeds 0 (`>= 1`) for 2 consecutive 1-minute periods (`threshold = 0`, `period = 60`, `evaluation_periods = 2`, `Maximum`).
  3. `damolak-dev-healthy-hosts-low`: Fires when Target Group `HealthyHostCount` drops below 1 in 1 minute (`threshold = 1`, `period = 60`, `evaluation_periods = 1`, `Minimum`).
  4. `damolak-dev-cpu-high`: Fires when ECS average CPU utilization exceeds 80% for 2 consecutive 2-minute periods (`threshold = 80`, `period = 120`, `evaluation_periods = 2`, `Average`).
  5. `damolak-dev-app-log-errors`: Fires when structured JSON `ERROR` log entries exceed 0 (`>= 1`) in 1 minute (`threshold = 0`, `period = 60`, `evaluation_periods = 1`, `Sum`).

---

## Design Decisions & Architecture Decision Records (ADRs)

| Decision | Context & Justification | ADR Reference |
| :--- | :--- | :--- |
| **Compute Engine** | AWS ECS Fargate provides fully managed serverless containers without EC2 cluster maintenance overhead. | [ADR 0001](docs/adr/0001-record-architecture-decisions.md) |
| **Process Model** | Single Uvicorn worker process per container aligns task health directly with container liveness. | [ADR 0002](docs/adr/0002-fastapi-single-uvicorn-worker.md) |
| **State Storage** | S3 bucket with native lockfile locking provides distributed concurrency protection without DynamoDB tables. | [ADR 0003](docs/adr/0003-terraform-state-and-iam-scoping.md) |
| **Network Architecture** | Fargate tasks run in public subnets with direct egress to avoid NAT Gateway hourly charges (USD 0.046/hr). | [ADR 0004](docs/adr/0004-network-topology-and-private-subnets.md) |
| **Telemetry Costs** | ECS Container Insights is disabled to eliminate custom metric charges and remain within Free Tier credits. | [ADR 0005](docs/adr/0005-disable-ecs-container-insights.md) |
| **Decoupled ALB** | Load balancer is extracted into an independent module with a default 404 rule to support multi-service growth. | [ADR 0006](docs/adr/0006-decoupled-alb-and-multi-service-routing.md) |
| **CI Security** | Jenkins performs cloud deployment while GitHub Actions remains CI-only due to AWS Organization SCP denials. | [ADR 0007](docs/adr/0007-github-actions-ci-only-scp-oidc-block.md) |

---

## Assumptions

- Single AWS account and single region (`eu-north-1`).
- AWS Free plan credits fund the infrastructure under a `USD 40` budget alert guardrail.
- An AWS Organization Service Control Policy blocks IAM OIDC identity providers and operations outside `eu-north-1`.
- Public traffic uses HTTP (port 80) because no registered domain is available for an ACM TLS certificate.
- Development runs one Fargate task (`desired_count = 1`), creating a ~59-second availability gap during task replacement.
- The Jenkins controller runs locally in Docker (`127.0.0.1:8088`).
- The deployed runtime stack stays active only while Free plan credits last; `make down` removes hourly-billed resources.

---

## Limitations & Future Improvements

### Security Limitations & Upstream Vulnerabilities
- **ECR Basic Scan Findings:** Amazon ECR basic scanning reports 9 HIGH severity findings in Debian base packages (`util-linux`, `zlib`, `glibc`, `sqlite3`) for tag `7ef87f8` (`docs/evidence/deployment/ecr-scan-findings.json`). Trivy container scanning with `--ignore-unfixed` reports 0 HIGH or CRITICAL findings (no patched versions available at scan time). Base images refresh through Dependabot.
- **HTTP-Only Listener:** The current ALB listener operates on HTTP port 80. In production, configure an AWS Certificate Manager (ACM) TLS certificate with an HTTPS listener (port 443) and an HTTP-to-HTTPS redirect rule.
- **Single Task Availability Gap:** In development (`desired_count = 1`), task replacement creates an availability gap of ~59 seconds while Fargate provisions an ENI and passes health checks. Production requires `desired_count >= 2`.

### Future Roadmap
1. **HTTPS and ACM:** Provision Route 53 DNS records and validate ACM certificates for encrypted ingress.
2. **AWS WAF:** Attach AWS WAF to the ALB to inspect payloads and enforce IP rate limiting.
3. **Private Subnets with VPC Endpoints:** Relocate Fargate tasks to private subnets using AWS PrivateLink endpoints for ECR, SSM, and CloudWatch without deploying costly NAT Gateways.
4. **Multi-Environment Promotion:** Expand pipeline to promote images from `dev` to `staging` and `prod` with approval gates.
5. **Persistent Storage:** Integrate Amazon Aurora PostgreSQL Serverless v2 for stateful relational workloads.

---

## Verification

### Executed Checks
- **Unit tests and coverage:** `pytest` executes 19 tests across endpoints and metadata helpers, achieving 97.69% statement coverage against a 90% threshold.
- **Container build and read-only runtime:** Docker builds `damolak-api` (211 MB) and runs under `read_only: true` with a `/tmp` tmpfs mount, `appuser` (UID 10001), and `PYTHONDONTWRITEBYTECODE=1`.
- **Image and IaC scans:** `hadolint` lints `services/api/Dockerfile`, `trivy image --ignore-unfixed` reports 0 HIGH/CRITICAL findings, `trivy config` scans `infra/`, and ECR basic scan records baseline findings on push.
- **Terraform validation and tests:** `terraform fmt -check`, `terraform validate`, and `tflint` run across all four stacks (`bootstrap`, `shared`, `dev`, `prod`); `terraform test` runs for `bootstrap`, `shared`, `dev`, and modules (`network`, `ecs-service`, `alb`).
- **Idempotent plans:** `terraform plan` across `bootstrap`, `shared`, and `dev` reports 0 changes.
- **Alarm notification path:** `aws cloudwatch set-alarm-state` triggers SNS email delivery for `damolak-dev-alb-5xx` and `damolak-dev-healthy-hosts-low`, followed by automatic return to `OK`.
- **Task replacement timing:** Stopping the active ECS task (`aws ecs stop-task`) measures 59.0 seconds until a replacement task passes ALB health checks.
- **Deployed smoke test:** `scripts/smoke.sh` verifies `/api/v1/health/`, `/api/v1/info/` git SHA match, `/`, authenticated `POST /api/v1/echo/` (200 vs 401), and unknown route handling (404).
- **Full-history secret and hygiene scans:** `gitleaks detect --log-opts="--all"` and `scripts/check-hygiene.sh` scan the complete commit history and tracked files with 0 violations.
- **Destroy plan:** `terraform plan -destroy` on `dev` validates teardown without execution (0 to add, 0 to change, 36 to destroy).

### Not Executed
- ECS circuit-breaker rollback drill using a deliberately failing container image tag.
- Full `dev` destroy and rebuild cycle (`make down` followed by re-provisioning).

---

## Cost Analysis & Teardown

### Running Cost (`eu-north-1`, planning estimate)

Monthly estimates use a single 720-hour (30-day) planning estimate basis derived from AWS Price List on-demand rates in `eu-north-1`:

| Resource | Hourly Rate (USD) | Monthly Estimate (720 hrs, USD) | Notes |
| :--- | :--- | :--- | :--- |
| **Application Load Balancer (base)** | $0.02394 | $17.24 | Base hourly charge (`EUN1-LoadBalancerUsage`) |
| **ALB LCU (light traffic)** | $0.00076 | $0.55 | ~0.1 LCU at $0.00760/LCU-hr |
| **ALB Public IPv4 Addresses (2)** | $0.01000 | $7.20 | $0.00500/hr per public IP across 2 AZs |
| **Fargate Compute (0.25 vCPU)** | $0.01113 | $8.01 | 0.25 vCPU at $0.04450/vCPU-hr |
| **Fargate Memory (0.5 GB)** | $0.00245 | $1.76 | 0.5 GB at $0.00490/GB-hr |
| **Fargate Task Public IPv4 Address** | $0.00500 | $3.60 | 1 ENI public IP at $0.00500/hr |
| **Total Dev Rate (planning estimate)** | **$0.05328/hr** | **$38.36/mo** | ~$1.28/day |

### Teardown Procedure

The destroy path was validated by plan only (`terraform plan -destroy` reports 0 to add, 0 to change, 36 to destroy).

To stop all hourly charges when work is complete:

1. **Tier 1 Teardown (`make down`):**
   - **Removes:** 36 dev runtime resources (ALB, listener, rule, target group, ECS cluster, service, tasks, VPC, subnets, route tables, IGW, security groups, CloudWatch alarms, dashboard, log group, and SNS topic), reducing runtime costs to **$0.00/hr**.
   - **Preserves:** S3 state bucket (`damolak-tfstate-*-eu-north-1`), ECR repository and images (`damolak-api`), SSM API key parameter, AWS Budget, and CI IAM user.
   ```bash
   make down
   ```

2. **Tier 2 Teardown (`make nuke`):**
   - Destroys dev runtime resources, shared ECR and IAM resources, and empties the S3 state bucket for full account teardown.
   ```bash
   make nuke
   ```

3. **Verify Zero Billable Resources:**
   ```bash
   make cost-check
   ```

---

## Evidence Index

Project evidence files are stored with commit SHAs and UTC timestamps:

- **Application (Containerization & Local Quality):** [docs/evidence/application/](docs/evidence/application/)
- **Infrastructure (Terraform Architecture & Offline Verification):** [docs/evidence/infrastructure/](docs/evidence/infrastructure/)
- **Deployment (Bootstrap, ECR Push & Runtime Rollout):** [docs/evidence/deployment/](docs/evidence/deployment/)
- **Pipeline (Automated CI/CD Deployment):** [docs/evidence/pipeline/](docs/evidence/pipeline/)
- **Resilience (Idempotency Plans, Alarm Drill & Task Recovery):** [docs/evidence/resilience/](docs/evidence/resilience/)
