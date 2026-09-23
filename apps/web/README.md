# AI Workflow Studio web app

This is the React, TypeScript, Material UI, and Vite frontend for AI Workflow Studio.

## Local development

From the repository root, the recommended way to run the full local stack is:

```powershell
.\setup.ps1
.\run.ps1
```

The web application is then available at `http://localhost:5173`. The Vite
server proxies `/api` requests to the FastAPI container, so browser code uses
relative API paths and does not need a separate local API URL configuration.

To run only the frontend after dependencies have been installed:

```powershell
cd apps\web
npm run dev
```

The API and database must still be running for sign-in and session requests to
work. Start those with `docker compose up db api` from the repository root.

## Commands

```powershell
npm run dev      # Start Vite with hot module replacement
npm run lint     # Run ESLint
npm run build    # Type-check and create a production build
npm run preview  # Serve the production build locally
```

## Current application surface

- Provider-based sign-in for GitHub, Google, and Microsoft when configured
- Session-aware authentication state and sign-out
- A minimal authenticated dashboard placeholder for the future workflow editor

Material UI supplies the theme, baseline CSS, authentication controls, alerts,
loading state, app bar, avatar, and buttons. Product-specific layout and the
workflow-preview illustration remain lightweight CSS.

Authentication is cookie-based. The frontend must not store provider tokens,
application tokens, or cloud credentials in browser storage.
