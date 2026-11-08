"""FastAPI application factory and lifespan hooks."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.logging import configure_logging
from app.middleware import RequestContextMiddleware
from app.routes import echo, health, info, status

logger = logging.getLogger(__name__)

STATIC_DIR = Path(__file__).resolve().parent / "static"


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Record process start time and emit structured startup and shutdown logs."""
    settings = get_settings()
    configure_logging(settings.log_level)
    app.state.started_at = datetime.now(UTC)
    logger.info(
        "application starting env=%s version=%s sha=%s",
        settings.app_env,
        settings.app_version,
        settings.git_sha,
    )
    yield
    logger.info("application shutting down gracefully")


def create_app() -> FastAPI:
    """Construct and configure the FastAPI application instance."""
    settings = get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="Stateless HTTP telemetry and secret-verified echo API",
        lifespan=lifespan,
    )
    app.state.started_at = datetime.now(UTC)
    # TrustedHostMiddleware is intentionally omitted because ALB target group
    # health checks send the task's private IPv4 address in the Host header.
    app.add_middleware(RequestContextMiddleware)

    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

    app.include_router(status.router)
    app.include_router(health.router)
    app.include_router(info.router)
    app.include_router(echo.router)
    return app


app = create_app()
