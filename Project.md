# AI Workflow Studio --- Project Context & Architecture

> **Purpose:** This document is the primary high-level technical context
> for developers and coding agents (such as GitHub Copilot or Codex)
> working on AI Workflow Studio. It describes the product vision,
> architecture, technology choices, development environments,
> authentication model, cloud-provider integration model, and
> engineering conventions.
>
> This document should evolve as architectural decisions are made. When
> implementation and this document disagree, determine whether the
> implementation or documentation is outdated before introducing a new
> pattern.

------------------------------------------------------------------------

## 1. Project Overview

**AI Workflow Studio** is a cloud-agnostic visual platform for building
and executing AI workflows.

Users build workflows through a node-based graphical editor rather than
writing orchestration code directly. Nodes represent reusable operations
such as:

-   AI model inference
-   Text generation and summarization
-   Classification and translation
-   Document extraction and OCR
-   Image analysis
-   Speech-to-text and audio/video processing
-   REST API calls
-   Database operations
-   Storage operations
-   Conditional logic
-   Parallel execution
-   Loops
-   Caching
-   Human approval steps
-   Data visualization

A workflow is represented as a graph in which nodes exchange typed data
through edges.

Example:

``` text
Text Input
    │
    ▼
Prompt Template
    │
    ▼
LLM Generation
    │
    ▼
JSON Parser
    │
    ├───────────────┐
    ▼               ▼
REST API        Database
```

The platform is intended to support workflows that combine services from
multiple providers, including:

-   Microsoft Azure
-   Amazon Web Services (AWS)
-   Google Cloud Platform (GCP)
-   OpenAI
-   Local/self-hosted models
-   Generic external APIs

The platform must not assume that a workflow belongs to a single cloud
provider.

------------------------------------------------------------------------

## 2. Core Product Philosophy

### 2.1 Everything Is a Node

The central abstraction of the platform is the **Node**.

AI models, APIs, databases, transformations, conditional logic, document
processors, storage operations, visualizations, and human approval steps
should all participate in workflows through a common node contract.

The workflow engine should operate on generic node interfaces rather
than contain provider-specific execution logic.

For example, the engine should not need special knowledge of an
`OpenAIChatNode`. It should know how to validate and execute a `Node`.

``` text
                    Node Contract
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       AI Node       REST Node     Database Node
          │
          ▼
   Provider Abstraction
          │
   ┌──────┼──────┬──────┐
   ▼      ▼      ▼      ▼
 Azure   AWS    GCP   OpenAI
```

### 2.2 Cloud Agnostic

Workflow definitions should describe **capabilities and connections**,
not tightly couple the entire platform to one cloud.

Provider-specific behavior belongs behind provider adapters.

### 2.3 Visual First

The primary interaction model is a visual workflow editor. Users should
be able to:

-   Drag nodes onto a canvas
-   Connect compatible inputs and outputs
-   Configure node properties
-   Validate workflows
-   Execute workflows
-   Observe execution progress
-   Inspect node inputs and outputs
-   Inspect failures and logs
-   View latency and eventually cost information

### 2.4 Modular Monolith First

The initial backend should be a **modular monolith**, not a collection
of microservices.

Architectural boundaries should exist in code so components can
potentially be separated later, but deployment complexity should remain
low during early development.

------------------------------------------------------------------------

## 3. Initial Scope

The first meaningful vertical slice should prove:

``` text
Authenticate
    ↓
Dashboard
    ↓
Create Workflow
    ↓
Visual Workflow Editor
    ↓
Add + Connect Nodes
    ↓
Save Workflow
    ↓
Validate Workflow
    ↓
Execute Workflow
    ↓
Visualize Execution
    ↓
Inspect Inputs / Outputs / Errors / Latency
```

The first version should prioritize a reliable workflow engine and
editor over supporting a large number of AI providers or nodes.

A useful initial node set could include:

-   Text Input
-   Text Output
-   Prompt/Template
-   LLM Generation
-   JSON Parser
-   REST API
-   Conditional
-   Debug/Log

Advanced features such as distributed execution, marketplace support,
natural-language workflow generation, provider benchmarking, and complex
agent orchestration should come later.

------------------------------------------------------------------------

# 4. Technology Stack

## 4.1 Frontend

**Primary technologies:**

-   React
-   TypeScript
-   Vite
-   React Flow (or the current `@xyflow/react` package)
-   React Router
-   Material UI (MUI)
-   TanStack Query for server state
-   Zustand or equivalent lightweight store for complex editor/client
    state where appropriate
-   Vitest for unit/component testing
-   Playwright for end-to-end testing

React is preferred because the application is heavily centered around an
interactive node/graph editor, for which the React ecosystem has mature
tooling.

### Frontend Responsibilities

The frontend owns:

-   Authentication UI
-   Dashboard
-   Workflow listing/management
-   Visual workflow editor
-   Node palette
-   Node configuration UI
-   Edge creation/removal
-   Client-side graph interactions
-   Workflow validation feedback
-   Execution visualization
-   Execution history UI
-   Workspace/settings UI
-   Cloud connection management UI

Business-critical authorization and workflow execution must remain
server-side.

------------------------------------------------------------------------

## 4.2 Backend

**Primary technologies:**

-   Python
-   FastAPI
-   Pydantic
-   SQLAlchemy
-   Alembic
-   PostgreSQL driver (async-capable where appropriate)
-   Pytest
-   Ruff
-   MyPy or another static type checker

FastAPI exposes the REST API and coordinates authentication,
persistence, authorization, workflow execution, and provider
connections.

### Backend Responsibilities

The backend owns:

-   OAuth/OIDC callbacks
-   Application sessions
-   User accounts
-   Workspace membership
-   Authorization
-   Workflow CRUD
-   Workflow validation
-   Execution requests
-   Execution history
-   Workflow runtime integration
-   Node registry
-   Provider connections
-   Secret references
-   Audit-relevant operations
-   API contracts

FastAPI route handlers should remain thin. Core workflow logic should
live in reusable packages/services rather than directly inside route
handlers.

------------------------------------------------------------------------

## 4.3 Database

**Database:** PostgreSQL

**Hosted development database:** Neon PostgreSQL

**Local database:** PostgreSQL Docker container

Neon is used for the hosted `dev` environment because it provides
inexpensive/serverless PostgreSQL suitable for an early-stage, lightly
used development deployment.

The application should use standard PostgreSQL-compatible interfaces so
the database provider can be changed later without redesigning the
domain model.

### Initial Domain Entities

Expected entities include:

``` text
User
UserIdentity
Session
Workspace
WorkspaceMember
Workflow
WorkflowVersion (later if necessary)
Execution
NodeExecution
ProviderConnection
```

Additional entities should be introduced only when required.

------------------------------------------------------------------------

# 5. Environments

Initially there are only two environments:

``` text
LOCAL
DEV
```

Do not introduce staging or production infrastructure until it is
needed.

## 5.1 Local

Every developer should be able to run the application locally.

Expected topology:

``` text
React / Vite
     │
     ▼
FastAPI
     │
     ▼
PostgreSQL
```

Docker Compose should make local dependencies reproducible.

Typical command:

``` bash
docker compose up
```

Whether the frontend/backend run inside containers during active
development may be adjusted for developer experience, but PostgreSQL and
other shared infrastructure should be easy to start through Compose.

Local credentials must never be committed.

------------------------------------------------------------------------

## 5.2 Dev

`dev` is the only hosted environment initially.

Expected architecture:

``` text
                     GitHub
                        │
                 CI / Deployment
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
       React Frontend        FastAPI Container
             │                     │
 Azure Static Web Apps    Azure Container Apps
                                   │
                                   ▼
                           Neon PostgreSQL
                                   │
                       ┌───────────┼───────────┐
                       ▼           ▼           ▼
                     Azure        AWS       GCP/OpenAI
```

The environment is expected to receive very little traffic during early
development.

------------------------------------------------------------------------

# 6. Hosting Strategy

## 6.1 Frontend Hosting

The React application is hosted using **Azure Static Web Apps**.

Production builds are static assets generated by Vite:

``` bash
npm run build
```

The resulting frontend is deployed from GitHub through CI/CD.

## 6.2 API Hosting

The FastAPI backend is packaged as a Docker image and hosted using
**Azure Container Apps**.

For the early dev environment:

``` text
Minimum replicas: 0
```

Scale-to-zero is preferred because the environment will be lightly used.

The architecture should not depend on Azure-specific application APIs
simply because the backend is hosted on Azure.

## 6.3 Database Hosting

Hosted development uses **Neon PostgreSQL**, not Azure Database for
PostgreSQL initially.

This keeps idle infrastructure costs low while preserving a normal
PostgreSQL interface.

------------------------------------------------------------------------

# 7. Containerization

Docker is a first-class part of the project.

Goals:

-   Reproducible local environments
-   Consistent backend packaging
-   Easy CI builds
-   Cloud-portable runtime
-   Minimal host-machine dependencies

Expected repository files include:

``` text
docker-compose.yml
apps/api/Dockerfile
apps/web/Dockerfile        # optional depending on local/deployment strategy
```

Docker Compose should initially coordinate local infrastructure such as
PostgreSQL and, if useful, the API/frontend.

Do not introduce Kubernetes during the initial stages.

------------------------------------------------------------------------

# 8. Authentication Architecture

Authentication has three separate concepts that must not be conflated:

``` text
Human Identity
      │
      ▼
Application Authentication
      │
      ▼
Application Authorization
      │
      ▼
Cloud / Workload Authentication
```

A user's Google/GitHub/Microsoft identity does **not** automatically
become the credential used to execute workflows in Azure, AWS, GCP, or
OpenAI.

------------------------------------------------------------------------

## 8.1 OAuth / OIDC Login Providers

AI Workflow Studio should support:

-   **GitHub**
-   **Google**
-   **Microsoft**

These providers authenticate human users into AI Workflow Studio.

The application should request the minimum scopes required for
login/identity.

Provider access for deeper integrations must be treated separately from
login.

For example, "Sign in with GitHub" must not automatically grant
repository write access.

------------------------------------------------------------------------

## 8.2 Internal User Identity

Never use a provider's user ID as the application's primary user ID.

Each user receives an internal UUID.

Conceptually:

``` text
users
--------------------------------
id
primary_email
display_name
created_at
updated_at
```

External identities are stored separately:

``` text
user_identities
--------------------------------
id
user_id
provider
provider_subject
email
created_at
```

This allows one internal user to eventually link multiple identities:

``` text
             AI Workflow Studio User
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       GitHub        Google      Microsoft
```

Account-linking behavior must be implemented carefully; do not
automatically merge accounts solely because two providers report the
same email address.

------------------------------------------------------------------------

# 9. Session Management

The browser-facing application should use **server-side sessions with
secure cookies**, rather than requiring React to store application JWT
bearer tokens.

OAuth/OIDC authenticates the user initially. After successful
authentication, FastAPI creates an AI Workflow Studio session.

Flow:

``` text
User
  │
  ▼
Google / GitHub / Microsoft
  │
  │ OAuth/OIDC
  ▼
FastAPI callback
  │
  ├── Validate provider response
  ├── Find/create internal user
  └── Create application session
              │
              ▼
        HttpOnly Cookie
              │
              ▼
            Browser
              │
              ▼
         REST API calls
              │
              ▼
       Resolve session/user
```

The session cookie should use appropriate security attributes,
typically:

``` text
HttpOnly
Secure                 # hosted environments
SameSite=Lax           # adjust only if architecture requires otherwise
Path=/
```

The exact cookie/domain configuration depends on how the frontend and
API domains are deployed.

### Session Storage

Initially, sessions may be persisted in PostgreSQL.

Example conceptual schema:

``` text
sessions
--------------------------------
id
user_id
expires_at
created_at
last_accessed_at
```

The actual session identifier stored in the browser should be an opaque,
high-entropy value. Prefer storing a hash of the session token
server-side rather than the raw token when practical.

Redis is **not required initially** for four or five developers/users.
It may be introduced later if session/request scale warrants it.

### REST API Authentication

Browser REST requests rely on the session cookie.

React should not store authentication JWTs in `localStorage`.

If the project later exposes a public API, CLI, SDK, or
machine-to-machine interface, that interface may use API credentials or
bearer access tokens separately from browser sessions.

------------------------------------------------------------------------

# 10. CSRF and Browser Security

Because browser authentication uses cookies, state-changing endpoints
must account for CSRF.

At minimum:

-   Use an appropriate `SameSite` cookie policy.
-   Validate request origins where appropriate.
-   Add CSRF tokens if deployment topology or cross-site requirements
    make them necessary.
-   Configure CORS narrowly.
-   Never use wildcard credentialed CORS.
-   Do not expose provider credentials to the browser.
-   Escape/sanitize untrusted rendered content where required.
-   Use HTTPS in hosted environments.

Frontend and backend deployment domains should be chosen with cookie and
CORS behavior in mind.

------------------------------------------------------------------------

# 11. Authorization

Authentication answers:

> Who is this user?

Authorization answers:

> What is this user allowed to do?

Authorization belongs to AI Workflow Studio, not to
Google/GitHub/Microsoft.

The application should be workspace-oriented.

Conceptually:

``` text
Workspace
   │
   ├── Users / Members
   ├── Workflows
   ├── Executions
   └── Provider Connections
```

A future role model might include:

``` text
Owner
Admin
Developer
Viewer
```

Do not trust workspace IDs or resource IDs supplied by the frontend
without verifying that the current user is authorized to access them.

------------------------------------------------------------------------

# 12. Cloud Provider Authentication

Cloud authentication is independent from human OAuth login.

Do **not** create Azure, AWS, GCP, and OpenAI accounts for each AI
Workflow Studio user.

Instead, introduce a first-class **ProviderConnection /
CloudConnection** concept.

``` text
Workspace
    │
    ▼
Provider Connections
    │
    ├── Azure
    ├── AWS
    ├── GCP
    └── OpenAI
```

Connections are generally owned by a workspace rather than an individual
user.

A workflow references a connection by ID:

``` json
{
  "type": "llm-generation",
  "connectionId": "connection-uuid"
}
```

Credentials must never be embedded directly into workflow JSON.

------------------------------------------------------------------------

## 12.1 AWS

Prefer temporary credentials through **cross-account IAM role
assumption**.

Conceptual flow:

``` text
AI Workflow Studio
        │
        │ STS AssumeRole
        ▼
Customer AWS Account
        │
        ▼
Restricted IAM Role
        │
        ├── Bedrock
        ├── S3
        └── other explicitly permitted resources
```

Use least privilege and appropriate external-ID protections for
multi-tenant third-party access.

Avoid storing permanent AWS access-key pairs where federation/role
assumption is available.

------------------------------------------------------------------------

## 12.2 GCP

Prefer **Workload Identity Federation** rather than storing long-lived
service-account JSON keys.

Conceptual flow:

``` text
AI Workflow Studio
        │
        ▼
Workload Identity Federation
        │
        ▼
Customer GCP Project
        │
        ▼
IAM-authorized resources
```

------------------------------------------------------------------------

## 12.3 Azure

Prefer application/workload identity and Azure RBAC rather than using a
human user's Azure login as the runtime credential.

Conceptually:

``` text
AI Workflow Studio Workload
          │
          ▼
Microsoft Entra ID
          │
          ▼
Customer Azure Resources
          │
          ▼
Least-Privilege RBAC
```

Exact cross-tenant onboarding/authentication mechanics should be
designed when Azure provider integration is implemented.

------------------------------------------------------------------------

## 12.4 OpenAI

OpenAI should use an appropriate project/service credential supported by
the provider.

If a long-lived secret must be stored, store it in a dedicated
secret-management system rather than plaintext in PostgreSQL.

------------------------------------------------------------------------

# 13. Secret Management

General rule:

> Prefer federated identity and short-lived credentials over stored
> long-lived secrets.

Preference order:

``` text
1. Federated/workload identity
2. Temporary credentials
3. Role assumption
4. Vault-managed service/API secret
5. Long-lived credentials only when unavoidable
```

Never place provider credentials in:

-   Workflow JSON
-   Frontend state
-   Browser storage
-   Git
-   Logs
-   Plaintext database columns
-   Committed `.env` files

For hosted environments, Azure Key Vault is a potential secret store for
credentials that cannot use federation.

PostgreSQL should store only metadata and secret references where
possible.

Example:

``` text
provider_connections
--------------------------------
id
workspace_id
provider
display_name
auth_type
configuration
secret_reference
created_at
updated_at
```

------------------------------------------------------------------------

# 14. Provider Abstraction Layer

The platform needs a provider abstraction layer so nodes can use
provider capabilities without coupling the workflow engine to individual
SDKs.

Conceptually:

``` text
                  Provider Interface
                         │
       ┌─────────────────┼─────────────────┐
       ▼                 ▼                 ▼
 Azure Adapter       AWS Adapter       GCP Adapter
                                             │
                         ┌───────────────────┘
                         ▼
                    OpenAI Adapter
```

Provider adapters own provider-specific:

-   Authentication
-   SDK clients
-   API requests
-   Error normalization
-   Capability discovery where appropriate
-   Usage metadata
-   Provider-specific configuration

The workflow engine should interact with generic node/provider contracts
rather than directly instantiate cloud SDK clients.

------------------------------------------------------------------------

# 15. Node SDK

The Node SDK defines the contract for executable workflow components.

A node should eventually expose concepts similar to:

``` text
Node metadata
Node type/version
Input schema
Output schema
Configuration schema
Validation
Execution
Error handling
```

Conceptual Python interface:

``` python
class Node:
    async def validate(self, config, inputs):
        ...

    async def execute(self, context, inputs):
        ...
```

The exact interface may evolve, but provider-specific assumptions should
not leak into the base engine.

------------------------------------------------------------------------

# 16. Workflow Representation

A workflow is a graph containing:

-   Workflow metadata
-   Nodes
-   Edges
-   Node positions/UI metadata
-   Node configuration
-   Provider connection references

Example conceptual representation:

``` json
{
  "id": "workflow-uuid",
  "name": "Document Summarizer",
  "nodes": [
    {
      "id": "input-1",
      "type": "text-input",
      "position": { "x": 100, "y": 100 },
      "config": {}
    },
    {
      "id": "llm-1",
      "type": "llm-generation",
      "position": { "x": 400, "y": 100 },
      "config": {
        "connectionId": "connection-uuid"
      }
    }
  ],
  "edges": [
    {
      "source": "input-1",
      "target": "llm-1"
    }
  ]
}
```

Do not treat this example as the final schema. Introduce schema
versioning before workflow definitions become difficult to migrate.

------------------------------------------------------------------------

# 17. Workflow Validation

Before execution, the backend should validate the graph.

Validation should eventually include:

-   Unknown node types
-   Missing required configuration
-   Missing required inputs
-   Invalid edges
-   Incompatible input/output types
-   Invalid provider connection references
-   Unauthorized provider connections
-   Unsupported cycles
-   Invalid entry/exit conditions
-   Node-specific validation

Client-side validation can improve UX, but server-side validation
remains authoritative.

------------------------------------------------------------------------

# 18. Workflow Execution Engine

The first engine should execute dependency-based workflows reliably.

Initial responsibilities:

``` text
Workflow definition
        │
        ▼
Load + authorize
        │
        ▼
Validate graph
        │
        ▼
Determine execution order
        │
        ▼
Execute ready nodes
        │
        ▼
Pass outputs downstream
        │
        ▼
Persist status/results
```

Initial implementation should favor correctness and observability over
distributed scale.

Advanced features may later include:

-   Parallel execution
-   Conditional branches
-   Loops
-   Retry policies
-   Timeouts
-   Cancellation
-   Caching
-   Background execution
-   Distributed workers
-   Human-in-the-loop steps

------------------------------------------------------------------------

# 19. Execution Model and Observability

Executions should be first-class persisted entities.

Conceptually:

``` text
Execution
--------------------------------
id
workflow_id
workspace_id
status
started_at
completed_at
error
```

and:

``` text
NodeExecution
--------------------------------
id
execution_id
node_id
status
started_at
completed_at
input_metadata
output_metadata
error
latency
```

The UI should eventually visualize states such as:

``` text
Pending → Running → Succeeded
                  ↘ Failed
                  ↘ Cancelled
```

Execution views should expose useful debugging information while
ensuring secrets are redacted.

Future observability can include:

-   Latency
-   Token usage
-   Provider cost
-   Cache hits
-   Retries
-   Structured logs
-   Traces

------------------------------------------------------------------------

# 20. Repository Structure

Recommended monorepo structure:

``` text
ai-workflow-studio/
│
├── apps/
│   ├── web/                         # React + TypeScript frontend
│   └── api/                         # FastAPI application
│
├── packages/
│   ├── workflow-engine/             # Generic workflow runtime
│   ├── node-sdk/                    # Node contracts/interfaces
│   ├── nodes/                       # Built-in node implementations
│   │   ├── ai/
│   │   ├── document/
│   │   ├── vision/
│   │   ├── audio/
│   │   ├── workflow/
│   │   └── external/
│   │
│   └── providers/                   # Provider integrations
│       ├── azure/
│       ├── aws/
│       ├── gcp/
│       ├── openai/
│       └── local/
│
├── database/
│   ├── migrations/
│   ├── seeds/
│   └── scripts/
│
├── infrastructure/
│   ├── docker/
│   └── azure/
│
├── tests/
│   ├── integration/
│   └── e2e/
│
├── docs/
│   ├── architecture/
│   ├── adr/
│   └── development/
│
├── scripts/
│
├── .github/
│   ├── workflows/
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
│
├── .env.example
├── .gitignore
├── docker-compose.yml
├── CONTRIBUTING.md
├── LICENSE
├── PROJECT_CONTEXT.md
└── README.md
```

Do not create empty directories solely to match this diagram. Add them
as the corresponding functionality is implemented.

------------------------------------------------------------------------

# 21. Dependency Rules

Maintain these conceptual boundaries:

``` text
Web UI
  │
  ▼
REST API
  │
  ├── Application Services
  │
  ├── Workflow Engine
  │       │
  │       ▼
  │     Node SDK
  │       │
  │       ▼
  │     Nodes
  │
  ├── Provider Layer
  │
  └── Persistence
```

Important rules:

1.  The frontend never talks directly to PostgreSQL.
2.  The frontend never receives cloud-provider secrets.
3.  The workflow engine should not depend on FastAPI.
4.  Generic node contracts should not depend on React.
5.  Provider adapters should isolate cloud SDK details.
6.  API routes should not contain large amounts of business logic.
7.  Authorization must be enforced server-side.
8.  Workflow definitions reference provider connections, not
    credentials.

------------------------------------------------------------------------

# 22. Configuration

Use environment variables for deployment-specific configuration.

Commit:

``` text
.env.example
```

Never commit:

``` text
.env
.env.local
.env.dev
```

Example categories:

``` env
# Application
APP_ENV=
APP_URL=
API_URL=

# Database
DATABASE_URL=

# Session
SESSION_COOKIE_NAME=
SESSION_SECRET=

# OAuth/OIDC
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=
MICROSOFT_TENANT=

# Secret Management
AZURE_KEY_VAULT_URL=
```

Actual variable names may change as the implementation is created.

------------------------------------------------------------------------

# 23. CI/CD

GitHub is the source-control platform.

Pull requests should run automated checks before merging into `main`.

Expected frontend checks:

``` text
Install dependencies
Lint
Type check
Unit tests
Build
```

Expected backend checks:

``` text
Install dependencies
Ruff
Type checking
Pytest
Package/build validation
```

Deployment flow for `dev` should eventually resemble:

``` text
Feature Branch
      │
      ▼
Pull Request
      │
      ▼
CI
      │
      ▼
Merge to main
      │
      ├───────────────┐
      ▼               ▼
Deploy Web        Build API Image
      │               │
      ▼               ▼
Azure Static     Azure Container
 Web Apps             Apps
```

Database migrations should be handled deliberately during deployment
rather than being hidden side effects of application startup once the
project matures.

------------------------------------------------------------------------

# 24. Testing Strategy

Use multiple levels of testing.

### Unit Tests

Colocated with the component/package being tested.

Examples:

-   Node validation
-   Graph validation
-   Execution ordering
-   Provider error normalization
-   Authorization logic

### Integration Tests

Root-level integration tests may cover:

-   API + PostgreSQL
-   Workflow engine + node implementations
-   Session lifecycle
-   Provider adapter boundaries

### End-to-End Tests

Playwright should eventually cover critical browser workflows such as:

``` text
Login
→ Create workflow
→ Add nodes
→ Connect nodes
→ Save
→ Execute
→ Inspect result
```

External AI/cloud calls should generally be mocked or isolated in normal
CI unless a dedicated integration environment explicitly requires real
provider testing.

------------------------------------------------------------------------

# 25. Security Principles

Security is a core architectural concern because workflows may access
customer cloud resources.

Follow these principles:

1.  **Least privilege**
2.  **Short-lived credentials whenever possible**
3.  **No cloud secrets in workflow definitions**
4.  **No provider secrets in browser code**
5.  **No secrets in logs**
6.  **No secrets committed to Git**
7.  **Server-side authorization for every protected resource**
8.  **Workspace isolation**
9.  **Secure, HttpOnly session cookies**
10. **CSRF-aware cookie authentication**
11. **Narrow CORS configuration**
12. **Validate all workflow definitions server-side**
13. **Redact sensitive node inputs/outputs where necessary**
14. **Treat external node input/output as untrusted data**
15. **Audit sensitive connection-management operations**

------------------------------------------------------------------------

# 26. Git and Collaboration

The repository uses Git/GitHub.

Preferred workflow:

``` text
feature/chore/fix branch
        │
        ▼
Pull Request
        │
        ▼
Automated Checks
        │
        ▼
Review
        │
        ▼
main
```

Direct development on `main` should be avoided after initial repository
setup.

Use focused branches such as:

``` text
feature/workflow-editor
feature/session-auth
feature/github-oauth
feature/workflow-engine
fix/session-expiration
chore/docker-compose
```

The repository uses the Apache License 2.0.

------------------------------------------------------------------------

# 27. Architecture Decision Records

Significant architectural choices should be documented under:

``` text
docs/adr/
```

Examples:

``` text
0001-use-monorepo.md
0002-use-react-for-workflow-editor.md
0003-use-server-side-cookie-sessions.md
0004-provider-connection-model.md
0005-workflow-schema.md
```

An ADR should explain:

-   Context
-   Decision
-   Alternatives considered
-   Consequences

Do not silently introduce a second competing architectural pattern
without documenting why.

------------------------------------------------------------------------

# 28. Development Priorities

After the basic authentication/API/application shell, development should
prioritize:

``` text
1. Workflow CRUD + persistence
2. Basic visual workflow editor
3. Node SDK / node contract
4. Workflow validation
5. Basic execution engine
6. Execution persistence
7. Execution visualization/debugging
8. First real AI provider integration
9. ProviderConnection abstraction
10. Small core node library
11. Conditional/parallel/retry functionality
12. Additional Azure/AWS/GCP/OpenAI capabilities
```

Avoid prematurely building:

-   Kubernetes infrastructure
-   Microservices
-   A workflow marketplace
-   Dozens of providers
-   Dozens of nodes
-   Distributed execution
-   Complex agent orchestration
-   Production/staging infrastructure
-   Advanced billing

The first objective is proving the editor → persistence → validation →
execution → observability loop.

------------------------------------------------------------------------

# 29. Future Capabilities

Long-term possibilities include:

-   Natural-language workflow generation
-   AI-assisted workflow optimization
-   Multi-agent workflows
-   Multimodal workflows
-   Workflow templates
-   Custom plugin SDK
-   Workflow marketplace
-   Multi-provider benchmarking
-   Cost estimation
-   Latency estimation
-   Provider fallback
-   Model comparison
-   Human approval nodes
-   Dashboards and visualization nodes
-   Enterprise RBAC
-   Audit logs
-   Workflow versioning
-   Scheduled workflows
-   Event-triggered workflows
-   Public API / SDK / CLI
-   Distributed execution workers

These are future capabilities and should not dictate unnecessary
complexity in the MVP.

------------------------------------------------------------------------

# 30. Guidance for AI Coding Agents

When generating or modifying code for this repository:

1.  Preserve the architectural boundaries described in this document.
2.  Do not introduce a new framework, database, auth strategy,
    state-management library, cloud service, or major dependency without
    a clear reason.
3.  Prefer small, composable modules over large route
    handlers/components.
4.  Keep cloud-provider-specific logic behind provider adapters.
5.  Keep the workflow engine provider-agnostic.
6.  Use the Node SDK/contracts for executable workflow functionality.
7.  Never place provider credentials inside workflow definitions.
8.  Never expose secrets to the frontend.
9.  Use server-side authorization even when the frontend already hides
    an action.
10. Use secure cookie-based sessions for browser authentication unless
    an ADR explicitly changes this.
11. Treat GitHub, Google, and Microsoft as login identity providers, not
    workflow cloud credentials.
12. Prefer PostgreSQL-compatible functionality and migrations.
13. Maintain compatibility between local PostgreSQL and Neon PostgreSQL.
14. Keep local development reproducible with Docker/Docker Compose.
15. Assume `local` and `dev` are the only environments until
    documentation says otherwise.
16. Keep FastAPI routes thin.
17. Add tests for new core workflow-engine behavior.
18. Update documentation when architecture changes.
19. Do not prematurely convert modules into microservices.
20. Ask for clarification rather than inventing an architectural
    requirement that conflicts with this document.

------------------------------------------------------------------------

# 31. Current Architecture Summary

``` text
                           USERS
                             │
                ┌────────────┼────────────┐
                ▼            ▼            ▼
             GitHub        Google      Microsoft
                └────────────┼────────────┘
                             │
                        OAuth / OIDC
                             │
                             ▼
                    ┌────────────────┐
                    │ React + TS UI  │
                    │ Azure Static   │
                    │   Web Apps     │
                    └───────┬────────┘
                            │
                   Secure HttpOnly
                    Session Cookie
                            │
                            ▼
                    ┌────────────────┐
                    │    FastAPI     │
                    │ Azure Container│
                    │      Apps      │
                    └───────┬────────┘
                            │
          ┌─────────────────┼──────────────────┐
          ▼                 ▼                  ▼
   Workflow Engine      Persistence      Provider Layer
          │                 │                  │
          ▼                 ▼        ┌─────────┼──────────┐
       Node SDK        Neon PostgreSQL▼         ▼          ▼
          │                         Azure      AWS        GCP
          ▼                                      \
        Nodes                                      OpenAI
```

The hosting provider is an implementation detail. The core workflow
engine and node/provider abstractions should remain portable.

------------------------------------------------------------------------

# 32. Core Principle

When making architectural decisions, optimize for this goal:

> **A user should be able to visually compose reusable nodes from
> multiple providers into a workflow, execute it reliably, understand
> exactly what happened, and change providers without redesigning the
> workflow engine.**

Keep the early system simple enough for a small team to build and
operate, while preserving clean boundaries around the parts most likely
to grow: workflow execution, nodes, provider integrations,
authentication/authorization, and observability.
