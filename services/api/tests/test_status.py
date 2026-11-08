"""Tests for GET / status HTML page and duration formatting."""

from app.routes.status import format_duration
from fastapi.testclient import TestClient


def test_status_page_renders_telemetry_fields(client: TestClient) -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    html = response.text
    assert "damolak-api" in html
    assert "deadbeef1234" in html
    assert "eu-north-1" in html
    assert "/static/style.css" in html


def test_static_stylesheet_is_served_locally(client: TestClient) -> None:
    response = client.get("/static/style.css")
    assert response.status_code == 200
    assert "text/css" in response.headers["content-type"]
    assert "--bg:" in response.text


def test_format_duration_variants() -> None:
    assert format_duration(9) == "9s"
    assert format_duration(125) == "2m 5s"
    assert format_duration(3661) == "1h 1m 1s"
    assert format_duration(90061) == "1d 1h 1m 1s"
