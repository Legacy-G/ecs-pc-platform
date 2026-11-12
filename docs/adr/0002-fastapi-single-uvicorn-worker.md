# ADR 0002: FastAPI on Python 3.13 with a Single Uvicorn Process per Task

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

The platform requires a stateless HTTP telemetry service that exposes an HTML status page (`GET /`), a health check (`GET /api/v1/health/`), a JSON metadata endpoint (`GET /api/v1/info/`), an authenticated echo endpoint (`POST /api/v1/echo/`), and OpenAPI documentation. Each ECS Fargate task is sized at 256 CPU units (0.25 vCPU) and 512 MB memory in `eu-north-1`.

Two runtime questions must be settled:
1. Which Python web framework to use.
2. Whether to run Uvicorn directly as PID 1 or behind Gunicorn with multiple worker processes.

## Decision

Build the service with FastAPI (`0.162.2`), Pydantic v2 (`2.14.3`), and `pydantic-settings` (`2.16.2`) on Python `3.13.7` (`python:3.13-slim-bookworm` pinned by digest). Run a single Uvicorn process (`0.54.0`) as the container entrypoint with:
- `--proxy-headers` and `--forwarded-allow-ips` set from `FORWARDED_ALLOW_IPS` (VPC CIDR in AWS, `127.0.0.1` locally).
- `--timeout-graceful-shutdown 20`, paired with ECS `stopTimeout = 30` seconds and ALB target group `deregistration_delay = 30` seconds.

## Alternatives considered

1. **FastAPI with multi-worker Gunicorn:**
   Duplicated base interpreter memory across workers on a 0.25 vCPU core without throughput benefit, while ECS Fargate handles horizontal scaling.
2. **Flask with Gunicorn:**
   Lacks native asynchronous request handling, schema validation, and automatic OpenAPI generation.

## Consequences

- **Positive:** Lower memory footprint on 512 MB tasks, clean `SIGTERM` propagation to PID 1, automatic OpenAPI docs at `/docs`, and horizontal scaling managed solely by ECS Service Auto Scaling (1 to 2 tasks).
- **Negative / Limits:** CPU-bound request handlers would block the single event loop; all endpoints in this service are non-blocking or use bounded threadpool execution.
