# Authentication Reference

This document describes the authentication system that is implemented today.
It is a local-development foundation for browser users; it is not an API-token,
password, workspace-authorization, or cloud-provider-connection system.

## Overview

The application uses OAuth/OIDC identity providers to authenticate people and
then creates its own opaque, server-side session. A first successful provider
login creates an application user, so there is no separate password-based
sign-up form.

```text
Browser -> FastAPI -> Identity provider
   |          |             |
   |          |<-- code ----|
   |          |             |
   |<-- application cookies-|
   |
   `-- authenticated API calls with the session cookie --> FastAPI
```

The React application never stores an application JWT, provider access token,
or provider client secret. Provider access tokens exist only briefly in the
API process while it retrieves an identity profile.

## Components

| Component | Responsibility |
| --- | --- |
| React web app | Displays available providers, starts browser redirects, reads the non-HttpOnly CSRF cookie only for state-changing API calls, and renders the authenticated user. |
| FastAPI auth router | Provides provider discovery, OAuth start/callback, session lookup, and sign-out endpoints. |
| Authentication service | Creates and validates OAuth attempts, resolves identities, creates sessions, and restricts post-login redirects. |
| Provider registry | Defines OAuth/OIDC endpoints, scopes, token exchange, and profile normalization for GitHub, Google, and Microsoft. |
| PostgreSQL | Persists users, external identities, opaque session digests, and short-lived OAuth attempts. |

## Supported identity providers

A provider is available only when both its client ID and client secret are set
in `.env`.

| Provider | Required configuration | Requested scopes | Local callback URL |
| --- | --- | --- | --- |
| GitHub | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | `read:user user:email` | `http://localhost:8000/api/v1/auth/oauth/github/callback` |
| Google | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | `openid email profile` | `http://localhost:8000/api/v1/auth/oauth/google/callback` |
| Microsoft | `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, optionally `MICROSOFT_TENANT` | `openid email profile` | `http://localhost:8000/api/v1/auth/oauth/microsoft/callback` |

The provider callback URL is built from `API_URL`. The browser is returned to
`APP_URL` after a successful or failed login. Therefore, these values and the
registered provider callback must agree in every environment.

These are **human login identities only**. A GitHub, Google, or Microsoft
login does not give the application permission to execute workflows using that
person's cloud account.

## OAuth sign-in flow

1. The web app calls `GET /api/v1/auth/providers` and enables only configured
   provider buttons.
2. When the user selects a provider, the browser navigates to
   `GET /api/v1/auth/oauth/{provider}/start?return_to=/`.
3. The API creates a short-lived OAuth attempt, generating:
   - a random OAuth `state` value;
   - a separate random browser-binding token;
   - a PKCE code verifier and its SHA-256 (`S256`) challenge.
4. The API stores keyed digests of `state` and the browser-binding token in
   PostgreSQL, stores the PKCE verifier for the later token exchange, and sets
   the browser-binding token in a short-lived HttpOnly OAuth cookie.
5. The API redirects the browser to the selected provider's authorization
   endpoint with the provider scopes, state, callback URL, and PKCE challenge.
6. The provider redirects to
   `GET /api/v1/auth/oauth/{provider}/callback` with an authorization code and
   state.
7. The API locks and validates the OAuth attempt: provider name, expiry,
   one-time-use status, state digest, and browser-binding cookie digest must
   all match. The attempt is marked consumed before the provider token exchange
   so it cannot be replayed.
8. The API exchanges the code using the stored PKCE verifier, retrieves the
   provider profile, and creates or resolves the application identity.
9. The API creates an application session, sets session and CSRF cookies,
   deletes the temporary OAuth cookie, and redirects the browser to the safe
   local return path.

`return_to` is accepted only when it begins with one `/` and not `//`; all
other values become `/`. This prevents an OAuth callback from becoming an open
redirect.

If the user cancels the provider flow or a safe authentication failure occurs,
the API redirects to `/?auth_error=<message>` on `APP_URL`. The frontend
displays that message and removes it from the browser URL.

## Identity and account rules

`users` are internal application accounts with UUID primary keys. External
provider identities live separately in `user_identities` and are unique by
`(provider, provider_subject)`.

On first login, the application creates both a `users` row and a
`user_identities` row. On a later login with the same provider subject, it
uses the existing account and updates the external identity's last-login time,
email, verification flag, display name, and avatar URL.

The application **never joins accounts merely because their email addresses
match**. A person who signs in with a different provider currently receives a
separate application user unless explicit account linking is implemented in the
future.

The current session response contains the user's UUID, primary email, display
name, and avatar URL. The dashboard intentionally displays only the name and
avatar; the email remains available to authenticated frontend code through the
API response.

### Provider profile handling

- GitHub uses `/user`. If that profile has no email, the API calls
  `/user/emails` and chooses the primary verified address, or another verified
  address. Login fails when no verified address can be obtained.
- Google and Microsoft consume OIDC user-info claims. They require `sub` and
  either `email` or `preferred_username`.
- GitHub's profile email is currently treated as verified when it is present.
  Google relies on the `email_verified` claim. Microsoft treats the email as
  verified when its user-info response does not explicitly say otherwise.

## Application sessions

Successful authentication creates a random opaque session token and a separate
random CSRF token. The raw values are sent only as cookies. PostgreSQL stores
HMAC-SHA-256 digests keyed with `SESSION_SECRET`, so a leaked database row
cannot be used directly as a browser credential.

| Cookie | Default name | Purpose | JavaScript-readable | Path |
| --- | --- | --- | --- | --- |
| Session | `aiws_session` | Authenticates API requests | No (`HttpOnly`) | `/` |
| CSRF | `aiws_csrf` | Double-submit CSRF protection | Yes | `/` |
| OAuth attempt | `aiws_oauth` | Binds the callback to the browser that started it | No (`HttpOnly`) | `/api/v1/auth/oauth` |

All three use `SameSite=Lax`. Their `Secure` flag is controlled by
`COOKIE_SECURE`; it is `false` for local HTTP and must be `true` outside the
`local` environment. Cookie names, session duration, and OAuth attempt duration
are configurable. Defaults are a seven-day session (`SESSION_TTL_SECONDS=604800`)
and a ten-minute OAuth attempt (`OAUTH_TTL_SECONDS=600`, defined in code).

For every authenticated request, the API hashes the session cookie value and
looks up its `sessions` row. The request is rejected with `401` if the cookie
is absent, the row does not exist, the session is revoked or expired, or the
user is inactive. Valid requests update `last_accessed_at`; this is an audit
timestamp, not a sliding expiry.

## CSRF and browser protections

Cookie-based authentication requires CSRF protection on state-changing routes.
The current logout flow requires all of the following:

1. A valid session cookie.
2. An `X-CSRF-Token` header matching the JavaScript-readable CSRF cookie.
3. An HMAC digest of that header matching the CSRF digest stored with the
   session.
4. If the request supplies an `Origin` header, the origin must be in
   `CORS_ORIGINS`.

Comparisons of tokens and digests use constant-time comparison. FastAPI CORS is
credentialed but narrow: it allows configured origins, `GET`, `POST`, and
`OPTIONS`, and the `Content-Type` and `X-CSRF-Token` request headers. Wildcard
credentialed CORS is not enabled.

## API endpoints

All endpoints below are prefixed with `/api/v1/auth`.

| Method and path | Authentication | Behavior |
| --- | --- | --- |
| `GET /providers` | None | Returns an object marking each provider as configured or unavailable. |
| `GET /oauth/{provider}/start` | None | Creates an OAuth attempt, sets the temporary binding cookie, and returns a `307` redirect to the provider. |
| `GET /oauth/{provider}/callback` | OAuth state and binding cookie | Validates the callback, creates a session, clears the OAuth cookie, and returns a `307` redirect to the web app. |
| `GET /session` | Session cookie | Returns the authenticated user, or `401` if no valid session exists. Responses are `Cache-Control: no-store`. |
| `POST /logout` | Session cookie and CSRF header | Revokes the current session, clears the session/CSRF cookies, and returns `204 No Content`. |

The local API reference is available at `http://localhost:8000/api/docs` while
`APP_ENV=local`.

## Database records

| Table | Auth-relevant fields and purpose |
| --- | --- |
| `users` | Internal UUID, primary email, display name, avatar URL, active flag, and timestamps. |
| `user_identities` | Provider name and immutable provider subject, associated user, identity email/verification state, creation, and last-login timestamps. |
| `sessions` | User, keyed session and CSRF token digests, fixed expiry, creation/last-access timestamps, and optional revocation time. |
| `oauth_attempts` | Provider, keyed state/browser-token digests, PKCE verifier, safe return path, expiry, and one-time-use timestamp. |

The initial schema is defined by Alembic revision `20260919_0001`.

## Configuration

Copy `.env.example` to `.env`; `setup.ps1` does this automatically when no
`.env` exists and generates a local `SESSION_SECRET`. Never commit `.env`.

| Variable | Purpose |
| --- | --- |
| `APP_ENV` | `local` or `dev`; local enables API docs and permits non-Secure cookies. |
| `APP_URL` | Browser application origin used for post-login redirects. |
| `API_URL` | Public API origin used to construct OAuth callback URLs. |
| `CORS_ORIGINS` | Comma-separated trusted browser origins. |
| `DATABASE_URL` | Async SQLAlchemy PostgreSQL connection URL. |
| `SESSION_SECRET` | At least 32 characters; HMAC key for all stored browser-token digests. |
| `SESSION_COOKIE_NAME`, `CSRF_COOKIE_NAME`, `OAUTH_COOKIE_NAME` | Cookie-name overrides. |
| `SESSION_TTL_SECONDS` | Fixed lifetime for application sessions. |
| `COOKIE_SECURE` | Enables the `Secure` cookie attribute; required outside local. |
| Provider client variables | Enable GitHub, Google, or Microsoft sign-in when both ID and secret are present. |

Docker Compose overrides the API container's `DATABASE_URL` host from
`localhost` to the internal `db` service. It preserves the other values from
`.env`.

## Current boundaries and future work

- There are no local passwords, password resets, email verification flows, MFA,
  social account linking, organization membership checks, or role-based access
  controls yet.
- Sign-out revokes only the current application session. There is no
  all-devices session-management UI.
- Provider refresh/access tokens are deliberately not persisted; provider login
  credentials cannot yet be reused as workflow cloud connections.
- OAuth attempts are consumed, but expired attempts are not yet purged by a
  background cleanup job.
- Session expiry is fixed; renewal, rotation, absolute-session limits, and
  idle-session limits are not implemented.
- Hosted environments will need their own OAuth applications, HTTPS,
  `COOKIE_SECURE=true`, correct `APP_URL`/`API_URL`/`CORS_ORIGINS`, and reviewed
  cookie-domain behavior before deployment.

## Related documentation

- [Project architecture](Project.md)
- [Local setup and operations](../README.md)
- [Frontend guide](../apps/web/README.md)
