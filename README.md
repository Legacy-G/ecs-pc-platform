# ECS Platform Challenge

Stateless container platform deploying a FastAPI telemetry and echo service on AWS ECS Fargate behind an Application Load Balancer in region `eu-north-1`.

## Architecture Overview

- **Compute:** AWS ECS Fargate running Linux AMD64 containers with read-only root filesystems and tmpfs `/tmp`.
- **Networking:** Dedicated VPC (`10.20.0.0/16`) across two availability zones in `eu-north-1`.
- **Traffic Routing:** Application Load Balancer with independent HTTP target group, health checks, and a default 404 listener.
- **Secrets Management:** Injected at container runtime from AWS Systems Manager Parameter Store as `SecureString` parameters without persisting secret values in Terraform state.
- **Observability:** Centralized CloudWatch log group, 5 CloudWatch metric alarms (ALB 5xx, unhealthy host count, healthy host count low, ECS CPU utilization, and structured application log errors), and an Amazon SNS topic for operational alerts.

## Security and Vulnerability Posture

ECR basic scan reports 9 HIGH severity vulnerabilities originating in base Debian 12 (bookworm) operating system packages (`sqlite3`, `zlib`, `util-linux`, `glibc`). None currently have patches available upstream from the Debian security team. Trivy image scanning with `--ignore-unfixed` reports 0 vulnerabilities. Base container images and dependencies are rebuilt and updated weekly through Dependabot.
