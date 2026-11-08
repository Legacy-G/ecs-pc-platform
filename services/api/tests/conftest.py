"""Shared pytest fixtures for API tests."""

from collections.abc import Iterator

import pytest
from app.config import Settings, get_settings
from app.main import create_app
from app.metadata import get_cached_task_metadata
from fastapi.testclient import TestClient


@pytest.fixture(autouse=True)
def clear_caches() -> Iterator[None]:
    """Reset settings and metadata caches before and after every test."""
    get_settings.cache_clear()
    get_cached_task_metadata.cache_clear()
    yield
    get_settings.cache_clear()
    get_cached_task_metadata.cache_clear()


@pytest.fixture
def test_settings() -> Settings:
    """Return deterministic Settings instance for unit tests."""
    return Settings(
        app_name="damolak-api",
        app_env="test",
        app_version="0.1.0",
        git_sha="deadbeef1234",
        aws_region="eu-north-1",
        log_level="INFO",
        forwarded_allow_ips="127.0.0.1",
        api_key="unit-test-secret-key",
        ecs_container_metadata_uri_v4=None,
    )


@pytest.fixture
def client(test_settings: Settings) -> Iterator[TestClient]:
    """Provide a FastAPI TestClient with overridden settings."""
    app = create_app()
    app.dependency_overrides[get_settings] = lambda: test_settings
    with TestClient(app) as test_client:
        yield test_client
