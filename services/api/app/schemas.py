"""Pydantic v2 request and response schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class HealthChecks(BaseModel):
    """Individual readiness check results."""

    model_config = ConfigDict(extra="forbid")

    config: str = Field(description="Configuration validation state")
    metadata: str = Field(description="ECS metadata endpoint reachability")


class HealthResponse(BaseModel):
    """Response model for GET /api/v1/health/."""

    model_config = ConfigDict(extra="forbid")

    status: str = Field(description="Overall service health status")
    checks: HealthChecks


class InfoResponse(BaseModel):
    """Response model for GET /api/v1/info/."""

    model_config = ConfigDict(extra="forbid")

    service: str
    version: str
    git_sha: str
    environment: str
    aws_region: str
    task_id: str
    availability_zone: str
    started_at: datetime
    uptime_seconds: float


class EchoRequest(BaseModel):
    """Request body for POST /api/v1/echo/."""

    model_config = ConfigDict(extra="forbid")

    message: str = Field(min_length=1, max_length=2048)
    attributes: dict[str, Any] = Field(default_factory=dict)


class EchoResponse(BaseModel):
    """Response body for POST /api/v1/echo/."""

    model_config = ConfigDict(extra="forbid")

    echo: str
    attributes: dict[str, Any]
    environment: str
    git_sha: str
    request_id: str
    received_at: datetime
