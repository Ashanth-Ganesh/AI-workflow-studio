from dataclasses import dataclass
from typing import Any
from urllib.parse import urlencode

import httpx

from ai_workflow_studio.core.config import Settings


class OAuthProviderError(RuntimeError):
    """Raised when an identity provider returns an invalid or incomplete response."""


@dataclass(frozen=True)
class IdentityProfile:
    subject: str
    email: str
    email_verified: bool
    display_name: str
    avatar_url: str | None = None


@dataclass(frozen=True)
class ProviderDefinition:
    name: str
    client_id: str | None
    client_secret: str | None
    authorization_endpoint: str
    token_endpoint: str
    userinfo_endpoint: str
    scopes: str

    @property
    def configured(self) -> bool:
        return bool(self.client_id and self.client_secret)

    def authorization_url(
        self, *, redirect_uri: str, state: str, challenge: str
    ) -> str:
        if not self.client_id:
            raise OAuthProviderError(f"{self.name} login is not configured")
        query = {
            "client_id": self.client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": self.scopes,
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
        return f"{self.authorization_endpoint}?{urlencode(query)}"

    async def exchange_code(
        self, *, code: str, redirect_uri: str, code_verifier: str
    ) -> str:
        if not self.configured:
            raise OAuthProviderError(f"{self.name} login is not configured")
        payload = {
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "code": code,
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
            "code_verifier": code_verifier,
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    self.token_endpoint,
                    data=payload,
                    headers={"Accept": "application/json"},
                )
                response.raise_for_status()
                token_payload = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise OAuthProviderError("The identity provider rejected the login request") from exc

        access_token = token_payload.get("access_token")
        if not isinstance(access_token, str) or not access_token:
            raise OAuthProviderError("The identity provider did not return an access token")
        return access_token

    async def fetch_profile(self, access_token: str) -> IdentityProfile:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    self.userinfo_endpoint,
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Accept": "application/json",
                        "X-GitHub-Api-Version": "2022-11-28",
                    },
                )
                response.raise_for_status()
                profile = response.json()
                if self.name == "github":
                    return await self._github_profile(client, access_token, profile)
                return self._oidc_profile(profile)
        except (httpx.HTTPError, ValueError, KeyError) as exc:
            raise OAuthProviderError("Unable to read the identity provider profile") from exc

    async def _github_profile(
        self, client: httpx.AsyncClient, access_token: str, profile: dict[str, Any]
    ) -> IdentityProfile:
        email = profile.get("email")
        email_verified = bool(email)
        if not email:
            response = await client.get(
                "https://api.github.com/user/emails",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                },
            )
            response.raise_for_status()
            emails = response.json()
            chosen = next(
                (item for item in emails if item.get("primary") and item.get("verified")),
                next((item for item in emails if item.get("verified")), None),
            )
            if chosen:
                email = chosen.get("email")
                email_verified = True
        if not email:
            raise OAuthProviderError("GitHub did not provide a verified email address")
        subject = profile.get("id")
        if subject is None:
            raise OAuthProviderError("GitHub did not provide a user identifier")
        return IdentityProfile(
            subject=str(subject),
            email=str(email).lower(),
            email_verified=email_verified,
            display_name=str(profile.get("name") or profile.get("login") or email),
            avatar_url=profile.get("avatar_url"),
        )

    def _oidc_profile(self, profile: dict[str, Any]) -> IdentityProfile:
        subject = profile.get("sub")
        email = profile.get("email") or profile.get("preferred_username")
        if not subject or not email:
            raise OAuthProviderError(
                "The identity provider did not return the required identity claims"
            )
        return IdentityProfile(
            subject=str(subject),
            email=str(email).lower(),
            email_verified=bool(profile.get("email_verified", self.name == "microsoft")),
            display_name=str(profile.get("name") or email),
            avatar_url=profile.get("picture"),
        )


class OAuthProviderRegistry:
    def __init__(self, settings: Settings) -> None:
        tenant = settings.microsoft_tenant
        self._providers = {
            "github": ProviderDefinition(
                name="github",
                client_id=settings.github_client_id,
                client_secret=settings.github_client_secret,
                authorization_endpoint="https://github.com/login/oauth/authorize",
                token_endpoint="https://github.com/login/oauth/access_token",
                userinfo_endpoint="https://api.github.com/user",
                scopes="read:user user:email",
            ),
            "google": ProviderDefinition(
                name="google",
                client_id=settings.google_client_id,
                client_secret=settings.google_client_secret,
                authorization_endpoint="https://accounts.google.com/o/oauth2/v2/auth",
                token_endpoint="https://oauth2.googleapis.com/token",
                userinfo_endpoint="https://openidconnect.googleapis.com/v1/userinfo",
                scopes="openid email profile",
            ),
            "microsoft": ProviderDefinition(
                name="microsoft",
                client_id=settings.microsoft_client_id,
                client_secret=settings.microsoft_client_secret,
                authorization_endpoint=f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize",
                token_endpoint=f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token",
                userinfo_endpoint="https://graph.microsoft.com/oidc/userinfo",
                scopes="openid email profile",
            ),
        }

    def get(self, name: str) -> ProviderDefinition:
        try:
            return self._providers[name]
        except KeyError as exc:
            raise OAuthProviderError(f"Unsupported OAuth provider: {name}") from exc

    def availability(self) -> dict[str, bool]:
        return {name: provider.configured for name, provider in self._providers.items()}
