from urllib.parse import parse_qs, urlparse

from ai_workflow_studio.core.config import Settings
from ai_workflow_studio.modules.auth.providers import OAuthProviderRegistry


def test_provider_authorization_url_uses_minimal_identity_scopes_and_pkce() -> None:
    settings = Settings(
        github_client_id="github-id",
        github_client_secret="github-secret",
    )
    provider = OAuthProviderRegistry(settings).get("github")

    url = provider.authorization_url(
        redirect_uri="http://localhost:8000/callback",
        state="random-state",
        challenge="pkce-challenge",
    )
    query = parse_qs(urlparse(url).query)

    assert query["scope"] == ["read:user user:email"]
    assert query["state"] == ["random-state"]
    assert query["code_challenge"] == ["pkce-challenge"]
    assert query["code_challenge_method"] == ["S256"]


def test_provider_availability_reflects_complete_credentials() -> None:
    settings = Settings(google_client_id="id-without-secret")

    assert OAuthProviderRegistry(settings).availability() == {
        "github": False,
        "google": False,
        "microsoft": False,
    }
