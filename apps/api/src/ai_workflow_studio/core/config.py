from functools import lru_cache
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    app_name: str = "AI Workflow Studio"
    app_env: Literal["local", "dev"] = "local"
    app_url: str = "http://localhost:5173"
    api_url: str = "http://localhost:8000"
    database_url: str = "postgresql+asyncpg://ai_studio:ai_studio@localhost:5432/ai_studio"
    cors_origins: str = "http://localhost:5173"

    session_cookie_name: str = "aiws_session"
    csrf_cookie_name: str = "aiws_csrf"
    oauth_cookie_name: str = "aiws_oauth"
    session_secret: str = "local-only-change-me-32-characters-minimum"
    session_ttl_seconds: int = 60 * 60 * 24 * 7
    oauth_ttl_seconds: int = 10 * 60
    cookie_secure: bool = False

    github_client_id: str | None = None
    github_client_secret: str | None = None
    google_client_id: str | None = None
    google_client_secret: str | None = None
    microsoft_client_id: str | None = None
    microsoft_client_secret: str | None = None
    microsoft_tenant: str = "common"

    @property
    def allowed_origins(self) -> list[str]:
        return [
            origin.strip().rstrip("/")
            for origin in self.cors_origins.split(",")
            if origin.strip()
        ]

    @model_validator(mode="after")
    def validate_security_settings(self) -> "Settings":
        if len(self.session_secret) < 32:
            raise ValueError("SESSION_SECRET must contain at least 32 characters")
        if self.app_env != "local" and not self.cookie_secure:
            raise ValueError("COOKIE_SECURE must be true outside the local environment")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
