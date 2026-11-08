# Requirements Traceability Matrix

This matrix maps every mandatory challenge requirement and project constraint to the repository file that satisfies it, the verification command, and current status.

## Mandatory Challenge Requirements

| ID | Requirement Summary | How Satisfied | Evidence Path | Verification Command | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | Provision cloud infrastructure with Terraform | All AWS infrastructure is managed through Terraform root stacks (`bootstrap`, `shared`, `dev`, `prod`) | `infra/` | `make tf-validate` | In Progress (Phase 0) |
| R2 | Modular, reusable, structured Terraform layout | Eight modules (`ecs-service`, `ecs-cluster`, `alb`, `network`, `ecr`, `observability`, `budget`, `iam`); generic `ecs-service` interface designed first | `infra/modules/` | `make tf-lint` | Planned (Phase 2) |
| R3 | CI/CD pipeline using Jenkins (preferred) or GitHub Actions | Local Jenkins controller via Docker Compose and Configuration-as-Code (`Jenkinsfile` primary) plus credential-free GitHub Actions CI workflow (`.github/workflows/ci.yml`) | `ci/jenkins/`, `Jenkinsfile`, `.github/workflows/ci.yml` | Jenkins build log in `docs/evidence/` | In Progress (Phase 1) |
| R4 | Pipeline stages for build, test, and deploy | Stages run linting, unit tests (`pytest`), image build, security scans, ECR push, `terraform plan`, `terraform apply`, and post-deploy smoke test | `Jenkinsfile`, `.github/workflows/ci.yml` | `make lint test scan` | In Progress (Phase 1) |
| R5 | Automated, repeatable AWS deployment on ECS, EC2, or EKS | ECS Fargate service running in two Availability Zones behind an Application Load Balancer in `eu-north-1` | `infra/envs/dev/` | `scripts/smoke.sh` | Planned (Phase 3) |
| R6 | Zero manual steps during standard deployment | Git push to `main` triggers build, scan, push, `terraform apply`, and HTTP smoke check against the ALB | `Jenkinsfile`, `scripts/smoke.sh` | Commit SHA matches `/api/v1/info/` | Planned (Phase 4) |
| R7 | Repeatable infrastructure lifecycle and zero drift | Second `terraform plan` returns exit code 0; full teardown and rebuild verified prior to submission | `docs/evidence/` | `terraform -chdir=infra/envs/dev plan -detailed-exitcode` | Planned (Phase 7) |
| R8 | Containerize application with Docker | Multi-stage `Dockerfile` on pinned `python:3.13-slim-bookworm` digest, non-root user (`10001`), built-in `HEALTHCHECK` | `services/api/Dockerfile`, `docker-compose.yml` | `docker compose up --build -d` | In Progress (Phase 1) |
| R9 | CloudWatch monitoring and logging | 7-day CloudWatch log group, JSON metric filters (`ERROR`, `5xx`), five CloudWatch alarms wired to SNS, and a service dashboard | `infra/modules/observability/` | Alarm drill evidence in `docs/evidence/` | Planned (Phase 6) |
| R10 | Clear README covering architecture, deployment, decisions, assumptions, and limits | Root `README.md` with architecture diagram, 15-minute reproduction steps, design trade-offs, cost table, and teardown instructions | `README.md` | `make prose` and fresh-clone test | Planned (Phase 8) |
| R11 | Public GitHub repository | Public repository at `https://github.com/Legacy-G/ecs-pc-platform` with feature-branch pull request history | `.git/config` | `git ls-remote origin` | Verified (Phase 0) |
| R12 | Detailed architecture and CI/CD diagrams | Diagram-as-code scripts generating PNG and SVG assets showing network, trust boundaries, and deployment flow | `docs/architecture/` | `make diagrams` | Planned (Phase 8) |
| R13 | Complete application, IaC, and pipeline source code | All source committed under `services/api/`, `infra/`, `ci/`, `.github/`, `scripts/`, and `docs/` | Repository root | `git status --short` | In Progress (Phase 0) |
| R14 | Original engineering decisions documented | Architecture Decision Records in `docs/adr/` covering runtime, compute, networking, state, secrets, and CI authentication | `docs/adr/` | `ls docs/adr/` | In Progress (Phase 0) |
| R15 | Accessible and runnable submission | Local one-command startup (`docker compose up`) and verified live deployment with captured evidence | `docker-compose.yml`, `docs/evidence/` | `make test` and `scripts/smoke.sh` | Planned (Phase 3 / 7) |

## Project Constraints and Quality Guardrails

| ID | Constraint | How Satisfied | Evidence Path | Verification Command | Status |
| --- | --- | --- | --- | --- | --- |
| C1 | Zero cash spend; stay within USD 40 of AWS Free Plan credits | Deployed in `eu-north-1` without NAT Gateway, RDS, or EKS; pre-apply cost printouts and post-destroy `scripts/cost-check.sh` | `scripts/cost-check.sh` | `bash scripts/cost-check.sh` | Verified (Phase 0) |
| C2 | No secrets or account IDs in git history | `.gitignore`, `.gitleaks.toml` (including 12-digit AWS account ID rule), pre-commit hook, and SSM `SecureString` for `X-API-Key` | `.gitignore`, `.gitleaks.toml` | `gitleaks detect --source . --verbose` | Verified (Phase 0) |
| C3 | Mandatory default tags on all AWS resources | Provider `default_tags` sets `Project`, `Environment`, `ManagedBy=terraform`, and `Owner` across every root module | `infra/envs/*/providers.tf` | `make tf-validate` | Planned (Phase 2) |
| C4 | Automated cost guardrails and clean teardown | AWS Budget module with threshold alerts and `make destroy` target followed by `scripts/cost-check.sh` | `infra/modules/budget/`, `Makefile` | `bash scripts/cost-check.sh` | In Progress (Phase 0) |
| C5 | Pinned tool, provider, image, and plugin versions | Central `ci/versions.env` file referenced by `Makefile`, `Dockerfile`, pre-commit, Jenkins, and GitHub Actions | `ci/versions.env`, `.pre-commit-config.yaml` | `pre-commit run --all-files` | Verified (Phase 0) |
| C6 | Direct engineer prose with zero banned words or AI tells | Enforced by `scripts/check-prose.sh` in pre-commit and CI on every commit | `scripts/check-prose.sh` | `bash scripts/check-prose.sh` | Verified (Phase 0) |
