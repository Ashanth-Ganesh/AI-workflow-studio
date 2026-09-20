import uuid
from datetime import timedelta
from unittest.mock import AsyncMock, Mock

from ai_workflow_studio.core.config import Settings
from ai_workflow_studio.core.security import token_digest
from ai_workflow_studio.db.base import utc_now
from ai_workflow_studio.modules.auth.models import OAuthAttempt, Session, User, UserIdentity
from ai_workflow_studio.modules.auth.providers import IdentityProfile
from ai_workflow_studio.modules.auth.service import AuthenticationService


class ScalarResult:
    def __init__(self, value: object) -> None:
        self.value = value

    def scalar_one_or_none(self) -> object:
        return self.value


async def test_callback_creates_internal_user_identity_and_hashed_session() -> None:
    settings = Settings()
    state = "state-token"
    browser_token = "browser-token"
    attempt = OAuthAttempt(
        provider="google",
        state_digest=token_digest(state, settings.session_secret),
        browser_token_digest=token_digest(browser_token, settings.session_secret),
        code_verifier="verifier",
        return_to="/",
        expires_at=utc_now() + timedelta(minutes=5),
    )
    added: list[object] = []
    db = Mock()
    db.add.side_effect = added.append
    db.commit = AsyncMock()
    db.execute = AsyncMock(side_effect=[ScalarResult(attempt), ScalarResult(None)])

    async def assign_user_id() -> None:
        user = next(item for item in added if isinstance(item, User))
        user.id = uuid.uuid4()

    db.flush = AsyncMock(side_effect=assign_user_id)
    provider = Mock()
    provider.exchange_code = AsyncMock(return_value="provider-access-token")
    provider.fetch_profile = AsyncMock(
        return_value=IdentityProfile(
            subject="google-subject",
            email="person@example.com",
            email_verified=True,
            display_name="Example Person",
        )
    )
    providers = Mock()
    providers.get.return_value = provider

    authenticated, return_to = await AuthenticationService(
        db, settings, providers
    ).complete_oauth("google", "authorization-code", state, browser_token)

    identity = next(item for item in added if isinstance(item, UserIdentity))
    stored_session = next(item for item in added if isinstance(item, Session))
    assert return_to == "/"
    assert identity.user_id == authenticated.user.id
    assert identity.provider_subject == "google-subject"
    assert stored_session.token_digest != authenticated.token
    assert stored_session.token_digest == token_digest(authenticated.token, settings.session_secret)
    assert stored_session.csrf_digest == token_digest(
        authenticated.csrf_token, settings.session_secret
    )
    assert attempt.consumed_at is not None
