# ADR 0002: FastAPI on Python 3.13 with a Single Uvicorn Process per Task

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

The platform requires a stateless HTTP telemetry service that exposes an HTML status page (`GET /`), a health check (`GET /api/v1/health/`), a JSON metadata endpoint (`GET /api/v1/info/`), an authenticated echo endpoint (`POST /api/v1/echo/`), and OpenAPI documentation. Each ECS Fargate task is sized at 256 CPU units (0.25 vCPU) and 512 MB memory in `eu-north-1`.

Two runtime questions must be settled:
1. Which Python web framework to use.
2. Whether to run Uvicorn directly as PID 1 or behind Gunicorn with multiple worker processes.

## Options Considered

1. **FastAPI + single Uvicorn process per container (`uvicorn app.main:app`):**
   - Native Pydantic v2 request/response validation, `pydantic-settings` configuration, and built-in OpenAPI schema generation.
   - Single event loop in one process fits within a 0.25 vCPU slice without multi-worker memory duplication or context-switching overhead.
   - Direct `SIGTERM` handling with `--timeout-graceful-shutdown 20`.
2. **FastAPI + Gunicorn with `UvicornWorker` (multiple workers):**
   - Adds process-manager supervision inside the container, duplicating base interpreter memory across workers (~50-70 MB per worker) while sharing the same 0.25 vCPU core.
   - Redundant when ECS Fargate already supervises the container lifecycle and scales horizontally by adding tasks.
3. **Flask + Gunicorn:**
   - Requires external libraries for request schema validation and OpenAPI generation.

## Decision

Build the service with FastAPI (`0.162.2`), Pydantic v2 (`2.14.3`), and `pydantic-settings` (`2.16.2`) on Python `3.13.7` (`python:3.13-slim-bookworm` pinned by SHA-256 digest). Run a single Uvicorn process (`0.54.0`) as the container entrypoint with:
- `--proxy-headers` and `--forwarded-allow-ips` set from `FORWARDED_ALLOW_IPS` (the VPC CIDR in AWS, `127.0.0.1` locally), never `*` in production.
- `--timeout-graceful-shutdown 20`, paired with ECS `stopTimeout = 30` seconds and ALB target group `deregistration_delay = 25` seconds.

## Consequences

- **Positive:** Lower memory footprint on 512 MB tasks, clean `SIGTERM` propagation to PID 1, automatic OpenAPI docs at `/docs`, and horizontal scaling managed solely by ECS Service Auto Scaling (1 to 2 tasks).
- **Negative / Limits:** CPU-bound request handlers would block the single event loop; all endpoints in this service are non-blocking or use bounded threadpool execution.
