"""Runtime configuration loaded from environment variables."""

from functools import lru_cache

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Typed service settings backed by environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    app_name: str = Field(default="damolak-api", min_length=1)
    app_env: str = Field(default="local", min_length=1)
    app_version: str = Field(default="0.1.0", min_length=1)
    git_sha: str = Field(default="local-dev", min_length=1)
    aws_region: str = Field(default="eu-north-1", min_length=1)
    log_level: str = Field(default="INFO", pattern=r"^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$")
    forwarded_allow_ips: str = Field(default="127.0.0.1", min_length=1)
    api_key: SecretStr = Field(default=SecretStr("local-dev-only-replace-me"))
    ecs_container_metadata_uri_v4: str | None = Field(default=None)
    metadata_timeout_seconds: float = Field(default=0.5, gt=0.0, le=5.0)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached application settings."""
    return Settings()
