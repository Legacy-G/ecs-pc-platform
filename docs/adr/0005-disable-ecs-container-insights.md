# ADR 0005: Disabling ECS Container Insights for Cost Preservation

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

Amazon ECS Container Insights collects and aggregates container-level metrics and diagnostic telemetry into CloudWatch. However, Container Insights charges for CloudWatch custom metrics and ingested CloudWatch Logs performance events per task and per cluster. In an account constrained by a USD 40 credit limit, Container Insights can quickly generate unexpected charges.

The platform requirements mandate five specific CloudWatch alarms:
1. Target 5xx response count
2. Target group unhealthy host count
3. Service CPU utilization
4. Application error log events
5. Service healthy task/host availability

## Decision

Disable Container Insights on the ECS cluster (`setting { name = "containerInsights", value = "disabled" }`):
1. Use standard, free-tier AWS ECS metrics (`AWS/ECS` `CPUUtilization`, `MemoryUtilization`) for compute monitoring.
2. Use ALB metrics (`AWS/ApplicationELB` `HealthyHostCount`, `UnHealthyHostCount`, `HTTPCode_Target_5XX_Count`) to monitor application availability and instance health.
3. Replace the `ECS/ContainerInsights` `RunningTaskCount` alarm with `AWS/ApplicationELB` `HealthyHostCount`, which fires whenever the number of healthy serving targets drops below 1.
4. Capture application-level errors using a CloudWatch Logs metric filter `{ $.level = "ERROR" }` over the 7-day retention log group.

## Consequences

- **Positive:** Eliminates custom metric and log ingestion charges from Container Insights, preserving credits.
- **Negative / Limits:** Task-level disk and network I/O breakdowns are not captured in CloudWatch, but application availability and service alarms remain fully functional.
