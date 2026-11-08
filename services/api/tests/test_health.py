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


def test_health_returns_200_when_ecs_metadata_degraded(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def failing_get(url: str, timeout: float) -> httpx.Response:
        raise httpx.ConnectError("metadata unreachable", request=httpx.Request("GET", url))

    monkeypatch.setattr(httpx, "get", failing_get)
    settings = Settings(
        app_env="dev",
        api_key="unit-test-secret-key",
        ecs_container_metadata_uri_v4="http://169.254.170.2/v4/container-id",
    )
    app = create_app()
    app.dependency_overrides[get_settings] = lambda: settings
    with TestClient(app) as local_client:
        resp = local_client.get("/api/v1/health/")
    assert resp.status_code == 200
    assert resp.json() == {
        "status": "ok",
        "checks": {
            "config": "ok",
            "metadata": "degraded",
        },
    }


def test_proxy_headers_cidr_extracts_real_client_ip(
    capsys: pytest.CaptureFixture[str],
) -> None:
    from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

    app = create_app()
    wrapped = ProxyHeadersMiddleware(app, trusted_hosts="10.20.0.0/16,127.0.0.1")
    with TestClient(wrapped, client=("10.20.1.25", 50000)) as proxy_client:
        resp = proxy_client.get(
            "/api/v1/health/",
            headers={"X-Forwarded-For": "198.51.100.42, 10.20.1.25"},
        )
    assert resp.status_code == 200
    stdout = capsys.readouterr().out
    assert '"client_ip":"198.51.100.42"' in stdout
