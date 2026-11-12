# ADR 0006: Decoupled Application Load Balancer and Multi-Service Routing

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

The initial implementation combined the Application Load Balancer (ALB) and the ECS service inside a single `ecs-service` module. This design prevented deploying a second service or worker behind the same load balancer without provisioning duplicate load balancers (incurring an additional USD 0.0252/hr plus IPv4 costs per service) or causing resource contention.

## Decision

Split the Application Load Balancer into a dedicated `alb` module:
1. `infra/modules/alb`: Provisions the public ALB, the ALB security group (with HTTP TCP 80 ingress), and an HTTP listener whose default action returns a fixed `404 Not Found` response.
2. `infra/modules/ecs-service`: Provisions the target group, the listener rule (with configurable `priority` and `path_patterns`), ECS service, task definition, IAM execution/task roles, task security group, and autoscaling.
3. Decoupled security group egress: Each service provisions its own `aws_vpc_security_group_egress_rule` on the ALB security group targeting its own task security group.
4. Adding an additional service requires calling `module "ecs-service"` with distinct `service_name`, `listener_rule_priority`, and `path_patterns`.

## Alternatives considered

1. **Combined ALB and ECS service module:** Precludes multi-service routing and forces redundant load balancer provisioning per microservice.
2. **Dedicated reverse proxy container (e.g., NGINX on ECS):** Introduces extra container maintenance and compute overhead compared to native ALB path-based routing.

## Consequences

- **Positive:** Multiple services share a single ALB, saving at least USD 0.0339/hr (~USD 24.75/month) per additional service.
- **Negative / Limits:** Each service deployed to the shared listener must specify a unique integer priority and non-overlapping path pattern.
