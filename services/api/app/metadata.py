"""ECS Task Metadata Endpoint v4 client with in-process caching."""

import logging
from dataclasses import dataclass
from functools import lru_cache

import httpx

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class TaskMetadata:
    """Resolved ECS task identity and placement attributes."""

    task_id: str
    availability_zone: str
    reachable: bool


def parse_task_id(task_arn: str) -> str:
    """Extract the short task ID from a full ECS task ARN."""
    if not task_arn:
        return "local"
    parts = task_arn.rstrip("/").split("/")
    return parts[-1] if parts[-1] else "local"


def fetch_task_metadata(metadata_uri: str | None, timeout_seconds: float = 0.5) -> TaskMetadata:
    """Query ECS_CONTAINER_METADATA_URI_V4/task when running inside ECS Fargate."""
    if not metadata_uri:
        return TaskMetadata(task_id="local", availability_zone="local", reachable=False)

    task_url = f"{metadata_uri.rstrip('/')}/task"
    try:
        response = httpx.get(task_url, timeout=timeout_seconds)
        response.raise_for_status()
        payload = response.json()
        task_arn = str(payload.get("TaskARN", ""))
        az = str(payload.get("AvailabilityZone", "unknown"))
        return TaskMetadata(
            task_id=parse_task_id(task_arn),
            availability_zone=az,
            reachable=True,
        )
    except (httpx.HTTPError, ValueError) as exc:
        logger.warning("ECS metadata lookup failed: %s", exc)
        return TaskMetadata(task_id="unknown", availability_zone="unknown", reachable=False)


@lru_cache(maxsize=4)
def get_cached_task_metadata(
    metadata_uri: str | None, timeout_seconds: float = 0.5
) -> TaskMetadata:
    """Cache ECS task metadata for the lifetime of the container process."""
    return fetch_task_metadata(metadata_uri=metadata_uri, timeout_seconds=timeout_seconds)
