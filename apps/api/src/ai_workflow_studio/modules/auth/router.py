from typing import Annotated
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, Query, Request, Response, status
from fastapi.responses import RedirectResponse

from ai_workflow_studio.core.config import Settings
from ai_workflow_studio.core.dependencies import SettingsDependency
from ai_workflow_studio.db.base import utc_now
from ai_workflow_studio.db.dependencies import DbSession
from ai_workflow_studio.modules.auth.dependencies import (
    CsrfProtectedAuth,
    CurrentAuthDependency,
)
from ai_workflow_studio.modules.auth.providers import OAuthProviderError, OAuthProviderRegistry
from ai_workflow_studio.modules.auth.schemas import ProviderAvailabilityResponse, SessionResponse
from ai_workflow_studio.modules.auth.service import AuthenticationError, AuthenticationService

router = APIRouter(prefix="/auth", tags=["authentication"])


def get_provider_registry(settings: SettingsDependency) -> OAuthProviderRegistry:
    return OAuthProviderRegistry(settings)


ProviderRegistryDependency = Annotated[OAuthProviderRegistry, Depends(get_provider_registry)]


def get_auth_service(
    db: DbSession,
    settings: SettingsDependency,
    providers: ProviderRegistryDependency,
) -> AuthenticationService:
    return AuthenticationService(db, settings, providers)


AuthServiceDependency = Annotated[AuthenticationService, Depends(get_auth_service)]


@router.get("/providers", response_model=ProviderAvailabilityResponse)
async def list_providers(
    providers: ProviderRegistryDependency,
) -> ProviderAvailabilityResponse:
    return ProviderAvailabilityResponse(providers=providers.availability())


@router.get("/oauth/{provider_name}/start", status_code=status.HTTP_307_TEMPORARY_REDIRECT)
async def start_oauth(
    provider_name: str,
    service: AuthServiceDependency,
    settings: SettingsDependency,
    return_to: str = Query(default="/"),
) -> RedirectResponse:
    try:
        oauth_start = await service.begin_oauth(provider_name, return_to)
    except (AuthenticationError, OAuthProviderError) as exc:
        return _auth_error_redirect(settings, str(exc))

    response = RedirectResponse(oauth_start.authorization_url)
    response.headers["Cache-Control"] = "no-store"
    response.set_cookie(
        settings.oauth_cookie_name,
        oauth_start.browser_token,
        max_age=settings.oauth_ttl_seconds,
        httponly=True,
        secure=settings.cookie_secure,
        samesite="lax",
        path="/api/v1/auth/oauth",
    )
    return response


@router.get("/oauth/{provider_name}/callback")
async def oauth_callback(
    provider_name: str,
    request: Request,
    service: AuthServiceDependency,
    settings: SettingsDependency,
    code: str | None = Query(default=None),
    state: str | None = Query(default=None),
    error: str | None = Query(default=None),
) -> RedirectResponse:
    browser_token = request.cookies.get(settings.oauth_cookie_name)
    if error or not code or not state:
        response = _auth_error_redirect(settings, "Login was cancelled or rejected")
    else:
        try:
            authenticated, return_to = await service.complete_oauth(
                provider_name, code, state, browser_token
            )
            response = RedirectResponse(f"{settings.app_url.rstrip('/')}{return_to}")
            response.set_cookie(
                settings.session_cookie_name,
                authenticated.token,
                max_age=settings.session_ttl_seconds,
                httponly=True,
                secure=settings.cookie_secure,
                samesite="lax",
                path="/",
            )
            response.set_cookie(
                settings.csrf_cookie_name,
                authenticated.csrf_token,
                max_age=settings.session_ttl_seconds,
                httponly=False,
                secure=settings.cookie_secure,
                samesite="lax",
                path="/",
            )
        except (AuthenticationError, OAuthProviderError) as exc:
            response = _auth_error_redirect(settings, str(exc))

    response.delete_cookie(settings.oauth_cookie_name, path="/api/v1/auth/oauth")
    response.headers["Cache-Control"] = "no-store"
    return response


@router.get("/session", response_model=SessionResponse)
async def read_session(response: Response, auth: CurrentAuthDependency) -> SessionResponse:
    response.headers["Cache-Control"] = "no-store"
    return SessionResponse(user=auth.user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    response: Response,
    auth: CsrfProtectedAuth,
    db: DbSession,
    settings: SettingsDependency,
) -> None:
    auth.session.revoked_at = utc_now()
    await db.commit()
    response.delete_cookie(settings.session_cookie_name, path="/")
    response.delete_cookie(settings.csrf_cookie_name, path="/")
    response.headers["Cache-Control"] = "no-store"


def _auth_error_redirect(settings: Settings, message: str) -> RedirectResponse:
    query = urlencode({"auth_error": message})
    return RedirectResponse(f"{settings.app_url.rstrip('/')}/?{query}")
