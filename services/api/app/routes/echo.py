"""Authenticated echo endpoint verifying end-to-end SSM secret injection."""

import secrets
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status

from app.config import Settings, get_settings
from app.schemas import EchoRequest, EchoResponse

router = APIRouter(tags=["echo"])


def verify_api_key(
    settings: Annotated[Settings, Depends(get_settings)],
    x_api_key: Annotated[str | None, Header(alias="X-API-Key")] = None,
) -> None:
    """Compare caller X-API-Key header in constant time against configured secret."""
    expected = settings.api_key.get_secret_value().strip()
    if (
        not expected
        or not x_api_key
        or not secrets.compare_digest(x_api_key.encode("utf-8"), expected.encode("utf-8"))
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-API-Key header.",
        )


@router.post(
    "/api/v1/echo/",
    response_model=EchoResponse,
    dependencies=[Depends(verify_api_key)],
)
def post_echo(
    payload: EchoRequest,
    request: Request,
    settings: Annotated[Settings, Depends(get_settings)],
) -> EchoResponse:
    """Echo validated request payload with deployment metadata and request ID."""
    req_id = getattr(request.state, "request_id", "-")
    return EchoResponse(
        echo=payload.message,
        attributes=payload.attributes,
        environment=settings.app_env,
        git_sha=settings.git_sha,
        request_id=req_id,
        received_at=datetime.now(UTC),
    )
