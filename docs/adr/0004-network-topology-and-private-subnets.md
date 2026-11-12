# ADR 0004: Network Topology and Private Subnet Isolation

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

AWS VPC best practices recommend isolating compute workloads in private subnets behind a NAT Gateway. However, an AWS NAT Gateway in `eu-north-1` costs USD 0.046 per hour (USD 33.12 per 720-hour month, planning estimate) plus USD 0.046 per GB data processing (and USD 0.005 per hour for its public IPv4 address). On a USD 40 total credit budget, running a NAT Gateway alongside an Application Load Balancer (ALB) would exhaust the credit allowance in days.

For development (`dev`), workloads run in public subnets with direct egress to AWS public endpoints (ECR, CloudWatch Logs, SSM) over HTTPS (TCP 443), secured strictly by security groups that drop all non-443 egress and only accept ingress from the ALB.

For production (`prod`), private subnets and a NAT Gateway are required for full compliance with enterprise boundary isolation.

## Decision

The `network` module defines both public and private subnets, controlled by the `enable_private_subnets` and `enable_nat_gateway` variables:
1. In `dev`: `enable_private_subnets = false` and `enable_nat_gateway = false`. No private subnets, private route tables, NAT Gateways, or Elastic IPs are provisioned, eliminating all idle NAT Gateway charges ($0/month).
2. In `prod`: `enable_private_subnets = true` and `enable_nat_gateway = true`. Both private subnets and an Elastic IP + NAT Gateway are created, allowing tasks to run with `assign_public_ip = false`.
3. If `enable_nat_gateway = true` is passed, `create_private_subnets` is automatically evaluated as true to guarantee valid route targets.

## Alternatives considered

1. **VPC interface endpoints (PrivateLink):** Cost approximately USD 7.20/month per endpoint per AZ for ECR, CloudWatch, and SSM, exceeding the credit allowance.
2. **NAT Gateway in development:** Incurs USD 33.12 per 720-hour month (plus USD 3.60/month for its public IPv4 address) in base charges, which exhausts testing credits.

## Consequences

- **Positive:** Avoids USD 36.72 per 720-hour month in NAT Gateway and EIP charges in `dev`, keeping the infrastructure within the USD 40 credit ceiling.
- **Negative / Limits:** Tasks in `dev` require public IP assignment to reach AWS APIs and ECR. This is mitigated by restricting task security group egress strictly to TCP 443 and allowing ingress exclusively from the ALB security group.
