"""HTML deployment status page rendered with Jinja2."""

from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.config import Settings, get_settings
from app.metadata import get_cached_task_metadata
from app.routes.info import compute_uptime_seconds

router = APIRouter(tags=["status"])

TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "templates"
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))


def format_duration(seconds: float) -> str:
    """Format seconds as a compact human-readable duration string."""
    total = int(max(0, seconds))
    days, rem = divmod(total, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)
    if days > 0:
        return f"{days}d {hours}h {minutes}m {secs}s"
    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    if minutes > 0:
        return f"{minutes}m {secs}s"
    return f"{secs}s"


@router.get("/", response_class=HTMLResponse)
def get_status_page(
    request: Request,
    settings: Annotated[Settings, Depends(get_settings)],
) -> HTMLResponse:
    """Render HTML telemetry status page for browser verification."""
    started_at: datetime = getattr(request.app.state, "started_at", datetime.now(UTC))
    uptime_sec = compute_uptime_seconds(started_at)
    meta = get_cached_task_metadata(
        settings.ecs_container_metadata_uri_v4,
        settings.metadata_timeout_seconds,
    )
    context = {
        "service": settings.app_name,
        "version": settings.app_version,
        "git_sha": settings.git_sha,
        "environment": settings.app_env,
        "aws_region": settings.aws_region,
        "task_id": meta.task_id,
        "availability_zone": meta.availability_zone,
        "started_at": started_at.strftime("%Y-%m-%d %H:%M:%S UTC"),
        "uptime_seconds": uptime_sec,
        "uptime_human": format_duration(uptime_sec),
        "request_id": getattr(request.state, "request_id", "-"),
    }
    return templates.TemplateResponse(
        request=request,
        name="status.html",
        context=context,
    )
