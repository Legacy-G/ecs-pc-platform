# Requirements Traceability Matrix

This matrix maps every mandatory challenge requirement and project constraint to the repository file that satisfies it, the verification command, and the verified evidence path.

## Mandatory Challenge Requirements

| ID | Requirement Summary | How Satisfied | Code / Config Path | Evidence Path | Verification Command | Status |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Provision cloud infrastructure with Terraform | All AWS infrastructure is managed through Terraform root stacks (`bootstrap`, `shared`, `dev`, `prod`) | `infra/` | [idempotency.txt](evidence/phase5/idempotency.txt) | `make tf-validate` | Verified |
| R2 | Modular, reusable, structured Terraform layout | Modules for `ecs-service`, `ecs-cluster`, `alb`, `network`, `ecr`, `observability`, `budget`, and `iam` with strict input validation | `infra/modules/` | [evidence/phase2/](evidence/phase2/) | `make tf-lint` | Verified |
| R3 | CI/CD pipeline using Jenkins (primary) or GitHub Actions | Local Jenkins controller via Docker Compose and JCasC (`Jenkinsfile` primary) plus credential-free GitHub Actions CI workflow (`.github/workflows/ci.yml`) | `ci/jenkins/`, `Jenkinsfile`, `.github/workflows/ci.yml` | [jenkins-build.log](evidence/phase4/jenkins-build.log) | `docker ps`, Jenkins console log | Verified |
| R4 | Pipeline stages for build, test, and deploy | Declarative pipeline executing Lint, Unit Tests (`pytest`), Container Build, Trivy Scan, ECR Push, Terraform Plan/Apply, and Live Smoke Test | `Jenkinsfile`, `.github/workflows/ci.yml` | [stage-timings.txt](evidence/phase4/stage-timings.txt) | `make lint test scan` | Verified |
| R5 | Automated, repeatable AWS deployment on ECS Fargate | ECS Fargate service running in public subnets across two Availability Zones behind an Application Load Balancer in `eu-north-1` | `infra/envs/dev/` | [dev-plan.txt](evidence/phase3b/dev-plan.txt) | `scripts/smoke.sh` | Verified |
| R6 | Zero manual steps during standard deployment | Git push to `main` triggers automatic Jenkins SCM poll, build, scan, push, `terraform apply`, and HTTP smoke verification | `Jenkinsfile`, `scripts/smoke.sh` | [smoke-live.txt](evidence/phase4/smoke-live.txt) | `/api/v1/info/` Git SHA match | Verified |
| R7 | Repeatable infrastructure lifecycle and zero drift | Terraform plan across `bootstrap`, `shared`, and `dev` stacks confirms 0 to add, 0 to change, 0 to destroy | `infra/` | [idempotency.txt](evidence/phase5/idempotency.txt) | `terraform plan -detailed-exitcode` | Verified |
| R8 | Containerize application with Docker | Multi-stage `Dockerfile` on pinned `python:3.13-slim-bookworm` digest, non-root user (`appuser` UID 10001), read-only rootfs with tmpfs `/tmp`, built-in non-curl `HEALTHCHECK` | `services/api/Dockerfile`, `docker-compose.yml` | [evidence/phase1/](evidence/phase1/) | `docker compose up --build -d` | Verified |
| R9 | CloudWatch monitoring and logging | 7-day retention CloudWatch log group, JSON metric filters (`ERROR`, `5xx`), 5 CloudWatch alarms wired to SNS, and an operational dashboard | `infra/modules/observability/` | [alarm-drill.txt](evidence/phase5/alarm-drill.txt), [alarms.txt](evidence/phase3b/alarms.txt) | Alarm state transition & email delivery | Verified |
| R10 | Clear README covering architecture, deployment, decisions, assumptions, and limits | Root `README.md` containing architecture diagrams, reproduction steps, design decisions, limitations, cost table, and teardown | `README.md` | `README.md` | `bash scripts/check-prose.sh` | Verified |
| R11 | Public GitHub repository | Public repository at `https://github.com/Legacy-G/ecs-pc-platform` with feature branch and pull request history | `.git/config` | Pull Requests #1 through #28 | `git ls-remote origin` | Verified |
| R12 | Detailed architecture and CI/CD diagrams | Python diagram scripts producing SVG and PNG assets illustrating network boundaries, trust domains, and pipeline flow | `docs/architecture/` | [aws-architecture.png](architecture/aws-architecture.png), [cicd-flow.png](architecture/cicd-flow.png) | `make diagrams` | Verified |
| R13 | Complete application, IaC, and pipeline source code | All source code, infrastructure modules, configuration scripts, and tests committed in repository | Repository root | Git commit history | `git status --short` | Verified |
| R14 | Original engineering decisions documented | Architecture Decision Records in `docs/adr/` covering compute, networking, state, secrets, and CI permissions | `docs/adr/` | `docs/adr/` | `ls docs/adr/` | Verified |
| R15 | Accessible and runnable submission | Local one-command startup (`docker compose up`) and live cloud deployment verified against Application Load Balancer endpoint | `docker-compose.yml`, `docs/evidence/` | [smoke-live.txt](evidence/phase4/smoke-live.txt) | `curl /api/v1/health/` | Verified |

## Project Constraints and Quality Guardrails

| ID | Constraint | How Satisfied | Code / Config Path | Evidence Path | Verification Command | Status |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | Zero cash spend; stay within AWS Free Plan credits | Deployed in `eu-north-1` without NAT Gateway, RDS, or EKS; hourly dev rate USD 0.0574; credit balance monitored | `scripts/cost-check.sh` | [cost-check.txt](evidence/phase3b/cost-check.txt) | `bash scripts/cost-check.sh` | Verified |
| C2 | No secrets or account IDs in git history | `.gitignore`, `.gitleaks.toml` enforcing 12-digit account ID and secret pattern blocks, pre-commit hooks, and SSM `SecureString` | `.gitignore`, `.gitleaks.toml` | [gitleaks full history audit](evidence/phase5/) | `gitleaks detect --log-opts="--all"` | Verified |
| C3 | Mandatory default tags on all AWS resources | Provider `default_tags` sets `Project=damolak`, `ManagedBy=terraform`, `Owner=platform-team` across every stack | `infra/envs/*/providers.tf` | [evidence/phase2/](evidence/phase2/) | `make tf-validate` | Verified |
| C4 | Automated cost guardrails and clean teardown | AWS Budget module with threshold alerts, `scripts/cost-check.sh`, and teardown instructions in runbook | `infra/modules/budget/`, `scripts/cost-check.sh` | [cost-check.txt](evidence/phase3b/cost-check.txt) | `bash scripts/cost-check.sh` | Verified |
| C5 | Pinned tool, provider, image, and plugin versions | Central `ci/versions.env` referenced by `Makefile`, `Dockerfile`, pre-commit, Jenkins, and GitHub Actions | `ci/versions.env`, `.pre-commit-config.yaml` | [evidence/phase1/](evidence/phase1/) | `pre-commit run --all-files` | Verified |
| C6 | Direct engineer prose with zero banned words or AI tells | Enforced by `scripts/check-prose.sh` on every commit and verified in CI | `scripts/check-prose.sh` | [evidence/phase4/](evidence/phase4/) | `bash scripts/check-prose.sh` | Verified |
