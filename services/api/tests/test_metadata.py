"""Tests for ECS task metadata v4 client and JSON log formatter."""

import json
import logging

import httpx
import pytest
from app.logging import JsonLogFormatter, request_id_ctx
from app.metadata import fetch_task_metadata, parse_task_id


def test_parse_task_id() -> None:
    arn = "arn:aws:ecs:eu-north-1:account:task/damolak-dev/1a2b3c4d5e6f"
    assert parse_task_id(arn) == "1a2b3c4d5e6f"
    assert parse_task_id("") == "local"


def test_fetch_task_metadata_unset_returns_local() -> None:
    meta = fetch_task_metadata(None)
    assert meta.task_id == "local"
    assert meta.availability_zone == "local"
    assert meta.reachable is False


def test_fetch_task_metadata_handles_http_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def failing_get(url: str, timeout: float) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=httpx.Request("GET", url))

    monkeypatch.setattr(httpx, "get", failing_get)
    meta = fetch_task_metadata("http://169.254.170.2/v4/container-id", timeout_seconds=0.1)
    assert meta.task_id == "unknown"
    assert meta.availability_zone == "unknown"
    assert meta.reachable is False


def test_json_log_formatter_includes_request_id_and_extra_fields() -> None:
    formatter = JsonLogFormatter()
    token = request_id_ctx.set("req-999")
    try:
        record = logging.LogRecord(
            name="app.access",
            level=logging.INFO,
            pathname=__file__,
            lineno=10,
            msg="http request completed",
            args=(),
            exc_info=None,
        )
        record.method = "GET"
        record.path = "/api/v1/health/"
        record.status = 200
        record.duration_ms = 1.23
        parsed = json.loads(formatter.format(record))
        assert parsed["request_id"] == "req-999"
        assert parsed["method"] == "GET"
        assert parsed["path"] == "/api/v1/health/"
        assert parsed["status"] == 200
    finally:
        request_id_ctx.reset(token)
