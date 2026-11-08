"""JSON runtime telemetry endpoint used by post-deploy smoke verification."""

from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.config import Settings, get_settings
from app.metadata import get_cached_task_metadata
from app.schemas import InfoResponse

router = APIRouter(tags=["telemetry"])


def compute_uptime_seconds(started_at: datetime) -> float:
    """Return non-negative process uptime in seconds."""
    delta = (datetime.now(UTC) - started_at).total_seconds()
    return round(max(0.0, delta), 2)


@router.get("/api/v1/info/", response_model=InfoResponse)
def get_info(
    request: Request,
    settings: Annotated[Settings, Depends(get_settings)],
) -> InfoResponse:
    """Return version, git SHA, region, ECS task ID, and process uptime as JSON."""
    started_at: datetime = getattr(request.app.state, "started_at", datetime.now(UTC))
    meta = get_cached_task_metadata(
        settings.ecs_container_metadata_uri_v4,
        settings.metadata_timeout_seconds,
    )
    return InfoResponse(
        service=settings.app_name,
        version=settings.app_version,
        git_sha=settings.git_sha,
        environment=settings.app_env,
        aws_region=settings.aws_region,
        task_id=meta.task_id,
        availability_zone=meta.availability_zone,
        started_at=started_at,
        uptime_seconds=compute_uptime_seconds(started_at),
    )
