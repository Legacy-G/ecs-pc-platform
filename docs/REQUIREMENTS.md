# Requirements Traceability

This matrix maps project requirements and operational guardrails to their implementation paths and evidence files.

| Requirement | Implementation | Evidence |
| :--- | :--- | :--- |
| Provision cloud infrastructure with Terraform | Managed root stacks in `infra/bootstrap`, `infra/envs/shared`, and `infra/envs/dev` | [idempotency.txt](evidence/resilience/idempotency.txt) |
| Modular, structured Terraform architecture | Isolated modules under `infra/modules/` for compute, networking, security, storage, and telemetry | [infrastructure evidence](evidence/infrastructure/) |
| Automated CI/CD deployment pipeline | Pipeline controller via Docker Compose (`ci/jenkins/`) and GitHub Actions workflow (`.github/workflows/ci.yml`) | [jenkins-build.log](evidence/pipeline/jenkins-build.log) |
| Pipeline stages for build, test, and deploy | Declarative pipeline executing code hygiene, unit tests, image builds, container security scans, infrastructure execution, and live smoke tests | [pipeline-timings.txt](evidence/pipeline/pipeline-timings.txt) |
| Automated AWS deployment on ECS Fargate | ECS Fargate service in public subnets across two Availability Zones behind an Application Load Balancer in `eu-north-1` | [dev-plan.txt](evidence/deployment/dev-plan.txt) |
| Non-interactive deployment path | SCM polling on `main` triggers automated container build, ECR upload, Terraform execution, and endpoint verification | [smoke-live.txt](evidence/pipeline/smoke-live.txt) |
| Infrastructure lifecycle repeatability | Multi-stack plan execution confirms zero diff across bootstrap, shared, and runtime configurations | [idempotency.txt](evidence/resilience/idempotency.txt) |
| Application containerization | Pinned base digest multi-stage `Dockerfile`, non-root execution (`appuser` UID 10001), read-only rootfs with tmpfs `/tmp`, stdlib healthcheck | [application evidence](evidence/application/) |
| CloudWatch monitoring and alerting | 7-day retention log group, error metric filters, 5 metric alarms routed to SNS, and dashboard | [alarm-drill.txt](evidence/resilience/alarm-drill.txt), [alarms.txt](evidence/deployment/alarms.txt) |
| Operational and design documentation | Architecture diagrams, reproduction commands, design records, limitations, cost schedules, and teardown | [README.md](../README.md), [RUNBOOK.md](RUNBOOK.md), [manual-setup.md](manual-setup.md) |
| Public repository with pull request history | Git branch and pull request history under branch protection rules | GitHub pull request history |
| Architecture and delivery flow diagrams | Python scripts generating vector SVG and PNG assets for infrastructure and pipeline topology | [aws-architecture.png](architecture/aws-architecture.png), [cicd-flow.png](architecture/cicd-flow.png) |
| Architecture Decision Records | Formal records in `docs/adr/` covering compute, networking, state, secrets, and CI permissions | [docs/adr/](adr/) |
| Local and cloud execution targets | Local execution (`docker compose up`) and live cloud endpoint behind Application Load Balancer | [smoke-live.txt](evidence/pipeline/smoke-live.txt) |
| Controlled cloud expenditure | Single-container dev deployment without NAT Gateway or RDS; hourly tracking via `scripts/cost-check.sh` | [cost-check.txt](evidence/deployment/cost-check.txt) |
| Secret and account hygiene | Parameter Store `SecureString` for keys, pre-commit hygiene scans, zero committed account numbers | [hygiene audit](evidence/pipeline/jenkins-build.log) |
| Default resource tagging | Root provider configurations apply `Project`, `ManagedBy`, and `Environment` tags across all resources | [infrastructure evidence](evidence/infrastructure/) |
| Automated cost guardrails | AWS Budget threshold alarms and two-tier teardown targets (`make down`, `make nuke`) | [cost-check.txt](evidence/deployment/cost-check.txt) |
| Deterministic dependencies | Pinned tool, provider, and package versions declared in `ci/versions.env` | [application evidence](evidence/application/) |
| Technical prose standards | Automated hygiene validation enforcing factual technical statements | [hygiene script](../scripts/check-hygiene.sh) |
