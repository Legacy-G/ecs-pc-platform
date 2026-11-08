"""Tests for GET /api/v1/health/."""

import httpx
import pytest
from app.config import Settings, get_settings
from app.main import create_app
from fastapi.testclient import TestClient


def test_health_local_skips_metadata(client: TestClient) -> None:
    response = client.get("/api/v1/health/")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "checks": {
            "config": "ok",
            "metadata": "skipped",
        },
    }
    assert "X-Request-ID" in response.headers


def test_health_accepts_private_ip_host_header(client: TestClient) -> None:
    """ALB target group health checks send the task private IP in Host."""
    response = client.get("/api/v1/health/", headers={"Host": "10.20.1.45:8000"})
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_health_with_ecs_metadata_reachable(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_get(url: str, timeout: float) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "TaskARN": "arn:aws:ecs:eu-north-1:account:task/damolak-dev/9f8e7d6c5b4a",
                "AvailabilityZone": "eu-north-1a",
            },
            request=httpx.Request("GET", url),
        )

    monkeypatch.setattr(httpx, "get", fake_get)
    settings = Settings(
        api_key="unit-test-secret-key",
        ecs_container_metadata_uri_v4="http://169.254.170.2/v4/container-id",
    )
    app = create_app()
    app.dependency_overrides[get_settings] = lambda: settings
    with TestClient(app) as local_client:
        resp = local_client.get("/api/v1/health/")
    assert resp.status_code == 200
    assert resp.json()["checks"]["metadata"] == "ok"
