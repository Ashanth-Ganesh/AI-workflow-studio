from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from ai_workflow_studio.core.dependencies import SettingsDependency
from ai_workflow_studio.core.security import constant_time_equal, token_digest
from ai_workflow_studio.db.base import utc_now
from ai_workflow_studio.db.dependencies import DbSession
from ai_workflow_studio.modules.auth.models import Session, User


@dataclass(frozen=True)
class CurrentAuth:
    session: Session
    user: User


async def get_current_auth(
    request: Request,
    db: DbSession,
    settings: SettingsDependency,
) -> CurrentAuth:
    session_token = request.cookies.get(settings.session_cookie_name)
    if not session_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

    result = await db.execute(
        select(Session)
        .options(joinedload(Session.user))
        .where(Session.token_digest == token_digest(session_token, settings.session_secret))
    )
    application_session = result.scalar_one_or_none()
    now = utc_now()
    if (
        application_session is None
        or application_session.revoked_at is not None
        or application_session.expires_at <= now
        or not application_session.user.is_active
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session expired")
    application_session.last_accessed_at = now
    await db.commit()
    return CurrentAuth(session=application_session, user=application_session.user)


CurrentAuthDependency = Annotated[CurrentAuth, Depends(get_current_auth)]


async def require_csrf(
    request: Request,
    auth: CurrentAuthDependency,
    settings: SettingsDependency,
    csrf_header: Annotated[str | None, Header(alias="X-CSRF-Token")] = None,
) -> CurrentAuth:
    csrf_cookie = request.cookies.get(settings.csrf_cookie_name)
    origin = request.headers.get("origin")
    if origin and origin.rstrip("/") not in settings.allowed_origins:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Untrusted request origin"
        )
    if not csrf_header or not csrf_cookie or not constant_time_equal(csrf_header, csrf_cookie):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid CSRF token")
    expected = token_digest(csrf_header, settings.session_secret)
    if not constant_time_equal(expected, auth.session.csrf_digest):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid CSRF token")
    return auth


CsrfProtectedAuth = Annotated[CurrentAuth, Depends(require_csrf)]
