# `services/api`: Telemetry and Echo Service

Stateless FastAPI service built on Python 3.13 (`uvicorn` single-worker runtime) for ECS Fargate behind an Application Load Balancer.

## Endpoints

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/` | None | HTML status page rendered with Jinja2 (`version`, `git_sha`, `environment`, `aws_region`, `task_id`, `availability_zone`, `uptime`) |
| `GET` | `/api/v1/health/` | None | Liveness and readiness probe for container and ALB target group health checks |
| `GET` | `/api/v1/info/` | None | JSON payload containing the same telemetry fields as `/` |
| `POST` | `/api/v1/echo/` | `X-API-Key` | Constant-time verified secret check echoing request JSON with `request_id` and `git_sha` |
| `GET` | `/docs` | None | OpenAPI interactive documentation |

## Operational Guardrails

1. **ALB Proxy Headers and Health Check Host Header:**
   - Uvicorn runs with `--proxy-headers` and `--forwarded-allow-ips "${FORWARDED_ALLOW_IPS}"` (set to the VPC CIDR in ECS and `127.0.0.1` locally).
   - `TrustedHostMiddleware` is intentionally omitted because ALB target group health checks send the task's private IPv4 address in the `Host` header.
2. **Graceful `SIGTERM` Shutdown:**
   - Uvicorn runs as PID 1 (`exec` form in `Dockerfile`) with `--timeout-graceful-shutdown 20`, paired with ECS `stopTimeout = 30s` and ALB `deregistration_delay = 25s`.
3. **Container Health Check Start Period:**
   - The `Dockerfile` `HEALTHCHECK` sets `--start-period=20s` and calls `http://127.0.0.1:8000/api/v1/health/` using Python's standard library `urllib.request`, avoiding extra OS packages such as `curl`.
