"""Liveness and readiness probe endpoint for ALB and container health checks."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.config import Settings, get_settings
from app.metadata import get_cached_task_metadata
from app.schemas import HealthChecks, HealthResponse

router = APIRouter(tags=["health"])


@router.get("/api/v1/health/", response_model=HealthResponse)
def get_health(
    settings: Annotated[Settings, Depends(get_settings)],
) -> HealthResponse:
    """Return service readiness without enforcing Host header restrictions."""
    config_state = "ok" if settings.app_name and settings.api_key.get_secret_value() else "invalid"
    if settings.ecs_container_metadata_uri_v4:
        meta = get_cached_task_metadata(
            settings.ecs_container_metadata_uri_v4,
            settings.metadata_timeout_seconds,
        )
        metadata_state = "ok" if meta.reachable else "degraded"
    else:
        metadata_state = "skipped"

    return HealthResponse(
        status="ok",
        checks=HealthChecks(config=config_state, metadata=metadata_state),
    )
