# ADR 0004: Network Topology and Private Subnet Isolation

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

AWS VPC best practices recommend isolating compute workloads in private subnets behind a NAT Gateway. However, an AWS NAT Gateway in `eu-north-1` costs USD 0.045 per hour (approx USD 32.40 per month) plus USD 0.045 per GB data processing. On a USD 40 total credit budget, running a NAT Gateway alongside an Application Load Balancer (ALB) would exhaust the credit allowance in days.

For development (`dev`), workloads run in public subnets with direct egress to AWS public endpoints (ECR, CloudWatch Logs, SSM) over HTTPS (TCP 443), secured strictly by security groups that drop all non-443 egress and only accept ingress from the ALB.

For production (`prod`), private subnets and a NAT Gateway are required for full compliance with enterprise boundary isolation.

## Decision

The `network` module defines both public and private subnets, controlled by the `enable_private_subnets` and `enable_nat_gateway` variables:
1. In `dev`: `enable_private_subnets = false` and `enable_nat_gateway = false`. No private subnets, private route tables, NAT Gateways, or Elastic IPs are provisioned, eliminating all idle NAT Gateway charges ($0/month).
2. In `prod`: `enable_private_subnets = true` and `enable_nat_gateway = true`. Both private subnets and an Elastic IP + NAT Gateway are created, allowing tasks to run with `assign_public_ip = false`.
3. If `enable_nat_gateway = true` is passed, `create_private_subnets` is automatically evaluated as true to guarantee valid route targets.

## Consequences

- **Positive:** Saves over USD 32.40 per month in `dev`, allowing the entire challenge infrastructure to remain comfortably under the USD 40 credit ceiling.
- **Negative / Limits:** Tasks in `dev` require public IP assignment to reach AWS APIs and ECR. This is mitigated by restricting task security group egress strictly to TCP 443 and allowing ingress exclusively from the ALB security group.
