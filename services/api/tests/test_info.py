"""Tests for GET /api/v1/info/."""

from fastapi.testclient import TestClient


def test_info_returns_runtime_telemetry(client: TestClient) -> None:
    response = client.get("/api/v1/info/", headers={"X-Request-ID": "req-telemetry-01"})
    assert response.status_code == 200
    assert response.headers["X-Request-ID"] == "req-telemetry-01"
    body = response.json()
    assert body["service"] == "damolak-api"
    assert body["version"] == "0.1.0"
    assert body["git_sha"] == "deadbeef1234"
    assert body["environment"] == "test"
    assert body["aws_region"] == "eu-north-1"
    assert body["task_id"] == "local"
    assert body["availability_zone"] == "local"
    assert body["uptime_seconds"] >= 0.0
    assert "started_at" in body


def test_info_replaces_unsafe_request_id(client: TestClient) -> None:
    response = client.get("/api/v1/info/", headers={"X-Request-ID": "bad id with spaces!"})
    assert response.status_code == 200
    assert response.headers["X-Request-ID"] != "bad id with spaces!"
    assert len(response.headers["X-Request-ID"]) == 36
