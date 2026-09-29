from collections.abc import Callable, Iterator

import pytest
from ai_workflow_studio.core.config import Settings, get_settings
from ai_workflow_studio.main import app
from fastapi.testclient import TestClient


@pytest.fixture
def client(settings_factory: Callable[..., Settings]) -> Iterator[TestClient]:
    settings = settings_factory()
    app.dependency_overrides[get_settings] = lambda: settings
    try:
        with TestClient(app, follow_redirects=False) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.pop(get_settings, None)


def test_public_health_and_provider_endpoints(client: TestClient) -> None:
    assert client.get("/api/v1/health/live").json() == {"status": "ok"}
    response = client.get("/api/v1/auth/providers")

    assert response.status_code == 200
    assert set(response.json()["providers"]) == {"github", "google", "microsoft"}


def test_session_requires_cookie(client: TestClient) -> None:
    response = client.get("/api/v1/auth/session")

    assert response.status_code == 401
    assert response.json() == {"detail": "Not authenticated"}


def test_unconfigured_provider_returns_to_ui_with_safe_error(client: TestClient) -> None:
    response = client.get("/api/v1/auth/oauth/github/start")

    assert response.status_code == 307
    assert response.headers["location"].startswith("http://localhost:5173/?auth_error=")
