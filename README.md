# AI Workflow Studio

AI Workflow Studio is a cloud-agnostic visual platform for designing and testing AI workflows. This initial vertical slice provides an async FastAPI API, PostgreSQL persistence, OAuth/OIDC login, opaque server-side sessions, and a responsive React + Material UI authentication UI.

## Prerequisites

To run setup, you need the project files (clone with Git or download a ZIP),
an internet connection, and a supported shell:

- Windows PowerShell or PowerShell 7 on Windows, or Bash on macOS/Linux

The scripts use Python 3.13, Node.js 20.19+ or 22.12+ with npm, and Docker
with Compose. A normal `setup` run checks for these tools; the opt-in
installation flag installs missing tools on Windows, macOS, Ubuntu, and
Debian. Git is also installed when missing. A package manager may ask for
administrator access, and downloads require internet access.

The root-level PowerShell scripts serve Windows; the Bash scripts serve macOS
and Linux. All four scripts use the same `.env` and Docker Compose stack.

For a new Windows machine, `setup.ps1 -InstallPrerequisites` installs missing
Python 3.13, Node.js LTS, Git, and Docker Desktop through WinGet. If WinGet is
missing, the script first tries to register or repair Microsoft's App
Installer. An installer may require administrator approval or a new terminal
before its commands become available. Docker Desktop may also need a first
launch to accept its terms, finish WSL setup, or request a reboot.

`setup.ps1 -InstallDocker` remains available if only Docker Desktop should be
installed automatically.

On macOS, `bash setup.sh --install-prerequisites` bootstraps Homebrew if needed,
then installs missing Python 3.13, Node.js 24, Git, and Docker Desktop.
Homebrew or Docker Desktop may need your password or first-run approval.
macOS may also prompt for Apple Command Line Tools during Homebrew setup.
On Ubuntu/Debian, the same flag installs base packages, Python 3.13 via uv,
Node.js 24 via nvm, and Docker Engine with Compose. Other Linux distributions
can use `bash setup.sh` after installing these tools manually.

Automatic Linux installation uses the official [uv installer](https://docs.astral.sh/uv/getting-started/installation/),
[nvm installer](https://github.com/nvm-sh/nvm#installing-and-updating), and
[Docker development installer](https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script).
These download and execute upstream scripts only when you opt in. Review them
first if your machine has organization-specific software policies.

No script can supply your OAuth client credentials, accept Docker's license
on your behalf, enable firmware virtualization, or complete a required OS
reboot. The setup output calls out missing tools; finish any first-run prompts
before launching the app.

## Run locally

### Windows

1. Run the first-time setup script. It validates the Python and Node.js versions, creates or reuses `.venv`, installs Python and frontend dependencies, and creates `.env` from `.env.example` without overwriting an existing `.env`. It also reports which OAuth providers are configured without showing credential values:

   ```powershell
   .\setup.ps1
   ```

   On a new machine, use the opt-in installation flag:

   ```powershell
   .\setup.ps1 -InstallPrerequisites
   ```

   If an installer reports that a new terminal is needed, reopen PowerShell
   and run the same command again; existing `.env` is preserved.

2. Add credentials for one or more OAuth providers to `.env` (see callback URLs below). A new `.env` receives a unique `SESSION_SECRET` automatically; preserve or replace it only with another high-entropy value.
3. Start the stack. The launcher starts Docker Desktop only when its engine is unavailable, waits for it, then starts Compose:

   ```powershell
   .\run.ps1
   ```

4. Open `http://localhost:5173`. Local API documentation is at `http://localhost:8000/api/docs`.

The API container waits for PostgreSQL, applies the committed Alembic
migrations, and then starts FastAPI. The Vite development server proxies
`/api` requests to FastAPI. The launcher validates `.env`, Docker Compose,
and local ports; it checks the UI/API, prints recent startup logs and local
URLs, then follows new logs. Press `Ctrl+C` to stop the Compose services;
Docker Desktop remains available for other projects.

Use `.\run.ps1 -Detach` to run the stack in the background, or
`.\run.ps1 -NoBuild` to skip rebuilding images when Dockerfiles and
dependencies have not changed.

### macOS and Linux

1. Run `bash setup.sh` from the repository root. On a new macOS or
   Ubuntu/Debian machine, use `bash setup.sh --install-prerequisites` to
   install missing tools. The script creates `.venv`, installs Python and
   frontend dependencies, and creates `.env` with a unique `SESSION_SECRET`
   without overwriting an existing file.
2. Add at least one OAuth provider's client ID and secret to `.env`.
3. Run `bash run.sh`, then open `http://localhost:5173`. API docs are at
   `http://localhost:8000/api/docs`.

On macOS the launcher starts Docker Desktop when needed. On Linux, start your
Docker Engine before running it. If your Linux user lacks Docker socket access,
you can explicitly add `--enable-docker-group` to the first setup command
(or run it later) and then log out and back in. This grants your account
[root-level Docker privileges](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user);
do it only if that fits your machine's security policy. The launcher checks
Compose, ports, and the UI/API health endpoints; it prints startup logs and
the local URLs, then follows
new logs. Press `Ctrl+C` to stop the Compose services. The Docker engine and
database volume remain intact. Use `bash run.sh --detach` to leave the stack
running, or `bash run.sh --no-build` to skip image rebuilding. Running with
`bash` works even when a Git checkout does not preserve executable bits.

To run the processes directly instead, start the `db` Compose service, install `requirements.txt` into a Python environment, then from the repository root run `alembic -c apps/api/alembic.ini upgrade head` and `uvicorn --app-dir apps/api/src ai_workflow_studio.main:app --reload`. Start the frontend with `npm run dev` from `apps/web`.

Docker Compose publishes PostgreSQL on `localhost:5432`. Stop another local
PostgreSQL instance first if it already uses that port. Application state is
kept in the named `postgres_data` Docker volume; `Ctrl+C` in the attached
launcher stops the Compose services but intentionally leaves that volume and
the Docker engine intact.

## OAuth provider setup

Register these local callback URLs with the corresponding provider:

- GitHub: `http://localhost:8000/api/v1/auth/oauth/github/callback`
- Google: `http://localhost:8000/api/v1/auth/oauth/google/callback`
- Microsoft: `http://localhost:8000/api/v1/auth/oauth/microsoft/callback`

Only identity scopes are requested. A first successful provider login creates an internal user with its own UUID; later logins resolve the external identity. Identities are never merged solely because email addresses match.

For local team development, collaborators can use the same development OAuth
application after being given access to its client credentials through an
approved secret-sharing channel. Do not commit `.env` or reuse development
credentials in a hosted environment. Each hosted environment should have its
own OAuth application and callback URLs.

## Authentication design

- Authorization-code flow with PKCE, unpredictable state, and browser-bound OAuth attempts
- Opaque, high-entropy session and CSRF values in cookies; only keyed digests are stored in PostgreSQL
- `HttpOnly`, `SameSite=Lax` application sessions, with `Secure` required outside local development
- Double-submit CSRF validation and origin checks on state-changing browser endpoints
- Narrow credentialed CORS configuration
- No browser JWT or token storage and no provider tokens persisted after profile retrieval

The current tables are `users`, `user_identities`, `sessions`, and `oauth_attempts`. The API is organized into transport, authentication service/provider, persistence, schema, and configuration boundaries so subsequent workspace and workflow modules can grow independently.

For endpoint-level flow, cookie, database, provider-scope, and security details,
see the [authentication reference](Docs/Authentication.md).

## Repository layout

```text
apps/
  api/
    src/ai_workflow_studio/  # FastAPI package and modular capabilities
    alembic/                 # Database migration environment and revisions
    tests/                   # API and authentication tests
  web/                       # React + TypeScript + Material UI + Vite application
Docs/Project.md              # Product and architecture context
docker-compose.yml           # Local PostgreSQL, API, and web stack
setup.ps1                    # First-time developer setup
run.ps1                      # Local stack launcher
setup.sh                     # macOS/Linux developer setup
run.sh                       # macOS/Linux stack launcher
```

The implemented API capabilities are `auth` and `health`. Workflow editing,
execution, workspaces, and provider connections remain planned capabilities.

## Checks

On Windows:

```powershell
# Backend (from the repository root)
.\.venv\Scripts\python.exe -m ruff check .
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\alembic.exe -c apps/api/alembic.ini upgrade head --sql

# Frontend (from apps/web)
npm run lint
npm test
npm run build
```

On macOS/Linux, run the same checks with `.venv/bin/python -m ruff check .`,
`.venv/bin/python -m pytest`, and `.venv/bin/alembic -c apps/api/alembic.ini upgrade head --sql`.
Frontend commands are unchanged.

## Continuous integration

GitHub Actions runs the checks in `.github/workflows/ci.yml` on every push and
pull request. Once the workflow is on `main`, you can also start a run from the
repository's **Actions** tab.
The workflow runs API lint and tests, frontend lint, unit tests, and build,
plus Alembic migrations against a temporary PostgreSQL 17 database. No OAuth
credentials or local `.env` file are needed.
