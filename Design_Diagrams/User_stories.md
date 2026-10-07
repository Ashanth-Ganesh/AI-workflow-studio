# Configure Azure environment
**Tasks:**

- Create Azure accounts for primary developers of this story and configure a resource group and app registrations for the api and UI of the application.
- Configure Azure static web apps for the UI and Azure app services for the api so they can host the application.
- Optionally configure a key-vault to store OAuth credentials

**Use cases:**
- As a developer, I need a deployed environment of the full application to perform end-end testing




# Create Workflow CRUD Api


Develop a placeholder api route that performs CRUD operations with database using a temporary workflow object

**Use cases:**

- Completion of this story enables future of implementation of workflow CRUD operations simpler as the only primary changes needed to be made would be adding more attributes and respective validation logic to the workflow object.


# Design Database Architecture
Tasks:

Identify key relational tables needed for the database
Identify fields of data to be stored across all tables
Identify connecting fields (foreign keys) to establish a clear connection across all stored objects
Establish numeric relationships between stored record: 1:1, 1:M, M:1, M:M


# Setup CI pipeline
Use case:

As a developer, I want to automate health checks in the project repository and increase protection of the main branch.
As a project manager, I want to ensure automated integrity of the repository through running tests and linting


# Setup project documentation and platform funamentals

Setup Angular or React app using Vite
Setup FastAPI project with a configure virtual environment
Setup a documentation folder with at least 1 documentation markdown file