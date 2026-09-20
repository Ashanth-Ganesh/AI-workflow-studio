from ai_workflow_studio.main import app
from fastapi.testclient import TestClient


def test_public_health_and_provider_endpoints() -> None:
    with TestClient(app) as client:
        assert client.get("/api/v1/health/live").json() == {"status": "ok"}
        response = client.get("/api/v1/auth/providers")

    assert response.status_code == 200
    assert set(response.json()["providers"]) == {"github", "google", "microsoft"}


def test_session_requires_cookie() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/auth/session")

    assert response.status_code == 401
    assert response.json() == {"detail": "Not authenticated"}


def test_unconfigured_provider_returns_to_ui_with_safe_error() -> None:
    with TestClient(app, follow_redirects=False) as client:
        response = client.get("/api/v1/auth/oauth/github/start")

    assert response.status_code == 307
    assert response.headers["location"].startswith("http://localhost:5173/?auth_error=")
