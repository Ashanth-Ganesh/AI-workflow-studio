from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ai_workflow_studio.core.config import get_settings
from ai_workflow_studio.db.session import engine
from ai_workflow_studio.modules.auth.router import router as auth_router
from ai_workflow_studio.modules.health.router import router as health_router


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncGenerator[None]:
    yield
    await engine.dispose()


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/api/docs" if settings.app_env == "local" else None,
        redoc_url=None,
        openapi_url="/api/openapi.json" if settings.app_env == "local" else None,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "X-CSRF-Token"],
    )
    application.include_router(auth_router, prefix="/api/v1")
    application.include_router(health_router, prefix="/api/v1")
    return application


app = create_app()
