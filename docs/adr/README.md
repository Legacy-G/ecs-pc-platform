# Architecture Decision Records (ADRs)

This directory documents the key architectural choices, trade-offs, and governance policies for `ecs-pc-platform`.

| ADR | Title | Status | Date | Summary |
| :--- | :--- | :--- | :--- | :--- |
| [0001](0001-record-architecture-decisions.md) | Record Architecture Decisions | Accepted | 2026-11-08 | Adopt Michael Nygard's Architecture Decision Record format. |
| [0002](0002-fastapi-single-uvicorn-worker.md) | FastAPI Single Uvicorn Worker in Container | Accepted | 2026-11-08 | Run 1 uvicorn process per container to align scaling and health checks with Fargate task boundaries. |
| [0003](0003-terraform-state-and-iam-scoping.md) | Terraform State and IAM Scoping | Accepted | 2026-11-08 | Use S3 native locking with versioning, encryption, and scoped IAM policies; omit account IDs from committed code. |
| [0004](0004-network-topology-and-private-subnets.md) | Network Topology and Subnet Architecture | Accepted | 2026-11-09 | Deploy dev Fargate tasks directly to public subnets to eliminate NAT Gateway hourly charges (USD 0.046/hr). |
| [0005](0005-disable-ecs-container-insights.md) | Disable ECS Container Insights | Accepted | 2026-11-09 | Disable Container Insights to preserve Free Tier credits while retaining CloudWatch logs and metrics. |
| [0006](0006-decoupled-alb-and-multi-service-routing.md) | Decoupled ALB and Multi-Service Routing | Accepted | 2026-11-09 | Separate ALB infrastructure into an independent module with a default 404 listener for multi-service extensibility. |
| [0007](0007-github-actions-ci-only-scp-oidc-block.md) | GitHub Actions CI-Only Mirror via SCP OIDC Block | Accepted | 2026-11-08 | Restrict GitHub Actions to offline verification because AWS Organization SCP denies OIDC identity providers. |
