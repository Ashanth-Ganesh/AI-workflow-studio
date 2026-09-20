# AI Workflow Studio

AI Workflow Studio is a cloud-agnostic visual platform for designing and testing AI workflows. This initial vertical slice provides an async FastAPI API, PostgreSQL persistence, OAuth/OIDC login, opaque server-side sessions, and a responsive React authentication UI.

## Run locally

1. Run the first-time setup script. It creates or reuses `.venv`, installs Python and frontend dependencies, and creates `.env` from `.env.example` without overwriting an existing `.env`:

   ```powershell
   .\setup.ps1
   ```

   If Docker Desktop is not installed, use `.\setup.ps1 -InstallDocker` to install it through Winget. Docker Desktop must be opened once to accept its terms before use.

2. Add credentials for one or more OAuth providers to `.env` (see callback URLs below). A new `.env` receives a unique `SESSION_SECRET` automatically; preserve or replace it only with another high-entropy value.
3. Start the stack. The launcher starts Docker Desktop only when its engine is unavailable, waits for it, then starts Compose:

   ```powershell
   .\run.ps1
   ```

4. Open `http://localhost:5173`. Local API documentation is at `http://localhost:8000/api/docs`.

The API container waits for PostgreSQL, applies the committed Alembic migrations, and then starts FastAPI. The Vite development server proxies `/api` requests to FastAPI. The launcher waits for the services, checks the local UI/API, prints recent startup logs, and then displays the local URLs. It follows only new logs afterward; press `Ctrl+C` to stop the Compose services. Docker Desktop itself remains available for other projects and can be quit when you are done working.

Use `.\run.ps1 -Detach` to run the stack in the background, or `.\run.ps1 -NoBuild` to skip rebuilding images when the Dockerfiles and dependency files have not changed.

To run the processes directly instead, start the `db` Compose service, install `requirements.txt` into a Python environment, then from the repository root run `alembic -c apps/api/alembic.ini upgrade head` and `uvicorn --app-dir apps/api/src ai_workflow_studio.main:app --reload`. Start the frontend with `npm run dev` from `apps/web`.

## OAuth provider setup

Register these local callback URLs with the corresponding provider:

- GitHub: `http://localhost:8000/api/v1/auth/oauth/github/callback`
- Google: `http://localhost:8000/api/v1/auth/oauth/google/callback`
- Microsoft: `http://localhost:8000/api/v1/auth/oauth/microsoft/callback`

Only identity scopes are requested. A first successful provider login creates an internal user with its own UUID; later logins resolve the external identity. Identities are never merged solely because email addresses match.

## Authentication design

- Authorization-code flow with PKCE, unpredictable state, and browser-bound OAuth attempts
- Opaque, high-entropy session and CSRF values in cookies; only keyed digests are stored in PostgreSQL
- `HttpOnly`, `SameSite=Lax` application sessions, with `Secure` required outside local development
- Double-submit CSRF validation and origin checks on state-changing browser endpoints
- Narrow credentialed CORS configuration
- No browser JWT or token storage and no provider tokens persisted after profile retrieval

The current tables are `users`, `user_identities`, `sessions`, and `oauth_attempts`. The API is organized into transport, authentication service/provider, persistence, schema, and configuration boundaries so subsequent workspace and workflow modules can grow independently.

## Checks

```bash
# Backend
python -m ruff check .
python -m pytest
alembic upgrade head --sql

# Frontend (from apps/web)
npm run lint
npm run build
```
