"""Request ID propagation and structured JSON access log middleware."""

import logging
import re
import time
import uuid
from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.logging import request_id_ctx

logger = logging.getLogger("app.access")

SAFE_REQUEST_ID_RE = re.compile(r"^[a-zA-Z0-9._-]{1,64}$")


def resolve_request_id(header_value: str | None) -> str:
    """Accept a caller-supplied X-Request-ID only if it matches safe characters."""
    if header_value and SAFE_REQUEST_ID_RE.match(header_value):
        return header_value
    return str(uuid.uuid4())


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Attach a correlation ID to each request and emit one JSON access log line."""

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        req_id = resolve_request_id(request.headers.get("X-Request-ID"))
        token = request_id_ctx.set(req_id)
        request.state.request_id = req_id
        start_ns = time.perf_counter_ns()
        client_ip = request.client.host if request.client else "-"

        try:
            response = await call_next(request)
        except Exception:
            duration_ms = round((time.perf_counter_ns() - start_ns) / 1_000_000, 2)
            logger.exception(
                "unhandled request exception",
                extra={
                    "request_id": req_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status": 500,
                    "duration_ms": duration_ms,
                    "client_ip": client_ip,
                },
            )
            request_id_ctx.reset(token)
            raise

        duration_ms = round((time.perf_counter_ns() - start_ns) / 1_000_000, 2)
        response.headers["X-Request-ID"] = req_id
        log_level = logging.ERROR if response.status_code >= 500 else logging.INFO
        logger.log(
            log_level,
            "http request completed",
            extra={
                "request_id": req_id,
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": duration_ms,
                "client_ip": client_ip,
            },
        )
        request_id_ctx.reset(token)
        return response
