"""Runtime configuration loaded from environment variables."""

from functools import lru_cache

from pydantic import Field, SecretStr, model_validator
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
    api_key: SecretStr = Field(default=SecretStr(""))
    ecs_container_metadata_uri_v4: str | None = Field(default=None)
    metadata_timeout_seconds: float = Field(default=0.5, gt=0.0, le=5.0)

    @model_validator(mode="after")
    def validate_non_local_api_key(self) -> "Settings":
        """Refuse to start in non-local environments without a configured API key."""
        raw_key = self.api_key.get_secret_value().strip()
        if self.app_env.lower() != "local" and not raw_key:
            raise ValueError("API_KEY must be configured when APP_ENV is not 'local'.")
        return self


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached application settings."""
    return Settings()
