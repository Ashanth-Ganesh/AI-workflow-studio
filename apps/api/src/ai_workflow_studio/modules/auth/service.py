from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ai_workflow_studio.core.config import Settings
from ai_workflow_studio.core.security import pkce_challenge, random_token, token_digest
from ai_workflow_studio.db.base import utc_now
from ai_workflow_studio.modules.auth.models import OAuthAttempt, Session, User, UserIdentity
from ai_workflow_studio.modules.auth.providers import OAuthProviderRegistry


class AuthenticationError(RuntimeError):
    """A safe, user-facing authentication failure."""


@dataclass(frozen=True)
class OAuthStart:
    authorization_url: str
    browser_token: str


@dataclass(frozen=True)
class AuthenticatedSession:
    token: str
    csrf_token: str
    user: User


class AuthenticationService:
    def __init__(
        self,
        db: AsyncSession,
        settings: Settings,
        providers: OAuthProviderRegistry,
    ) -> None:
        self.db = db
        self.settings = settings
        self.providers = providers

    async def begin_oauth(self, provider_name: str, return_to: str) -> OAuthStart:
        provider = self.providers.get(provider_name)
        if not provider.configured:
            raise AuthenticationError(f"{provider_name.title()} login is not configured")

        state = random_token()
        browser_token = random_token()
        verifier = random_token(48)
        attempt = OAuthAttempt(
            provider=provider_name,
            state_digest=token_digest(state, self.settings.session_secret),
            browser_token_digest=token_digest(browser_token, self.settings.session_secret),
            code_verifier=verifier,
            return_to=self._safe_return_to(return_to),
            expires_at=utc_now() + timedelta(seconds=self.settings.oauth_ttl_seconds),
        )
        self.db.add(attempt)
        await self.db.commit()

        redirect_uri = self._callback_url(provider_name)
        return OAuthStart(
            authorization_url=provider.authorization_url(
                redirect_uri=redirect_uri,
                state=state,
                challenge=pkce_challenge(verifier),
            ),
            browser_token=browser_token,
        )

    async def complete_oauth(
        self, provider_name: str, code: str, state: str, browser_token: str | None
    ) -> tuple[AuthenticatedSession, str]:
        if not browser_token:
            raise AuthenticationError("The login attempt is missing its browser binding")

        digest = token_digest(state, self.settings.session_secret)
        result = await self.db.execute(
            select(OAuthAttempt).where(OAuthAttempt.state_digest == digest).with_for_update()
        )
        attempt = result.scalar_one_or_none()
        now = utc_now()
        if (
            attempt is None
            or attempt.provider != provider_name
            or attempt.consumed_at is not None
            or attempt.expires_at <= now
            or attempt.browser_token_digest
            != token_digest(browser_token, self.settings.session_secret)
        ):
            raise AuthenticationError("The login attempt is invalid or has expired")

        attempt.consumed_at = now
        verifier = attempt.code_verifier
        return_to = attempt.return_to
        await self.db.commit()

        provider = self.providers.get(provider_name)
        access_token = await provider.exchange_code(
            code=code,
            redirect_uri=self._callback_url(provider_name),
            code_verifier=verifier,
        )
        profile = await provider.fetch_profile(access_token)

        identity_result = await self.db.execute(
            select(UserIdentity).where(
                UserIdentity.provider == provider_name,
                UserIdentity.provider_subject == profile.subject,
            )
        )
        identity = identity_result.scalar_one_or_none()
        if identity:
            user = await self.db.get(User, identity.user_id)
            if user is None or not user.is_active:
                raise AuthenticationError("This account is not available")
            identity.last_login_at = utc_now()
            identity.email = profile.email
            identity.email_verified = profile.email_verified
            user.display_name = profile.display_name
            user.avatar_url = profile.avatar_url
        else:
            # Email equality alone must never link identities to an existing user.
            user = User(
                primary_email=profile.email,
                display_name=profile.display_name,
                avatar_url=profile.avatar_url,
            )
            self.db.add(user)
            await self.db.flush()
            self.db.add(
                UserIdentity(
                    user_id=user.id,
                    provider=provider_name,
                    provider_subject=profile.subject,
                    email=profile.email,
                    email_verified=profile.email_verified,
                )
            )

        authenticated_session = self._new_session(user)
        await self.db.commit()
        return authenticated_session, return_to

    def _new_session(self, user: User) -> AuthenticatedSession:
        token = random_token()
        csrf_token = random_token()
        self.db.add(
            Session(
                user_id=user.id,
                token_digest=token_digest(token, self.settings.session_secret),
                csrf_digest=token_digest(csrf_token, self.settings.session_secret),
                expires_at=utc_now() + timedelta(seconds=self.settings.session_ttl_seconds),
            )
        )
        return AuthenticatedSession(token=token, csrf_token=csrf_token, user=user)

    def _callback_url(self, provider_name: str) -> str:
        return f"{self.settings.api_url.rstrip('/')}/api/v1/auth/oauth/{provider_name}/callback"

    @staticmethod
    def _safe_return_to(return_to: str) -> str:
        return return_to if return_to.startswith("/") and not return_to.startswith("//") else "/"
