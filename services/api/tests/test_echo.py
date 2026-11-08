"""Tests for POST /api/v1/echo/ and non-local API key enforcement."""

import pytest
from app.config import Settings
from fastapi.testclient import TestClient
from pydantic import ValidationError


def test_echo_rejects_missing_api_key(client: TestClient) -> None:
    response = client.post("/api/v1/echo/", json={"message": "ping"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or missing X-API-Key header."


def test_echo_rejects_wrong_api_key(client: TestClient) -> None:
    response = client.post(
        "/api/v1/echo/",
        headers={"X-API-Key": "wrong-key"},
        json={"message": "ping"},
    )
    assert response.status_code == 401


def test_echo_accepts_valid_api_key(client: TestClient) -> None:
    response = client.post(
        "/api/v1/echo/",
        headers={
            "X-API-Key": "unit-test-secret-key",
            "X-Request-ID": "echo-check-42",
        },
        json={"message": "hello fargate", "attributes": {"attempt": 1}},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["echo"] == "hello fargate"
    assert data["attributes"] == {"attempt": 1}
    assert data["environment"] == "test"
    assert data["git_sha"] == "deadbeef1234"
    assert data["request_id"] == "echo-check-42"


def test_echo_rejects_extra_fields(client: TestClient) -> None:
    response = client.post(
        "/api/v1/echo/",
        headers={"X-API-Key": "unit-test-secret-key"},
        json={"message": "valid", "unexpected": "field"},
    )
    assert response.status_code == 422


def test_settings_refuses_non_local_startup_without_api_key() -> None:
    with pytest.raises(ValidationError, match="API_KEY must be configured"):
        Settings(app_env="dev", api_key="")
    with pytest.raises(ValidationError, match="API_KEY must be configured"):
        Settings(app_env="production", api_key="   ")
