# Phase 1, Step 2: User Authentication

**Goal:** Implement the complete token-based authentication and session management system as defined in the specification documents.

**Depends On:** [Step 1: Project Setup](./01-project-setup.md)

**Relevant Specs:**
*   `session_management.md`
*   `sso_authentication_flow.md`
*   `token_and_sync_strategy.md`

---

### Step-by-Step Implementation

1.  **Add Required Gems:**
    *   Add `devise` for authentication logic and `devise-jwt` for handling JWTs.

    ```ruby
    # Gemfile
    gem 'devise'
    gem 'devise-jwt'
    ```
    *   Run `bundle install`.

2.  **Initialize Devise:**
    *   Run the Devise installer.
    ```bash
    rails generate devise:install
    ```

3.  **Create User Model:**
    *   Generate a `User` model using Devise.
    ```bash
    rails generate devise User
    ```
    *   Open the generated migration file and add any additional fields required (e.g., `name`).
    *   Run the migration: `rails db:migrate`.

4.  **Configure Devise for JWT:**
    *   In `config/initializers/devise.rb`, configure the JWT secret and navigation formats. The secret should be loaded from Rails credentials.
    *   In the `User` model (`app/models/user.rb`), include the `devise-jwt` modules for JWT revocation.

5.  **Create Authentication Controllers:**
    *   Generate controllers to handle API requests. These should be scoped under an `Api::V1` module.
    *   Create `Api::V1::RegistrationsController` to handle user sign-ups.
    *   Create `Api::V1::SessionsController` to handle email/password login.
    *   Create `Api::V1::Auth::SsoController` to handle social sign-on.
    *   Create `Api::V1::Auth::RefreshController` to handle refresh token logic.

6.  **Define API Routes:**
    *   In `config/routes.rb`, define the routes for all authentication endpoints under the `/api/v1` namespace.
    *   Map the routes to the controllers created in the previous step.
    *   Ensure routes for `login`, `signup`, `logout`, `sso/:provider`, and `refresh` are present.

7.  **Implement Controller Logic:**
    *   **Registrations/Sessions:** Implement the standard Devise logic, ensuring they return the `access_token` and `refresh_token` in the response body upon success.
    *   **SSO Controller:** Implement the logic described in `sso_authentication_flow.md`. It will receive a provider token, verify it with the provider, find or create a user, and return your application's tokens.
    *   **Refresh Controller:** Implement the logic described in `session_management.md`. It will receive a refresh token, validate it, and return a new set of tokens.

### Acceptance Criteria

*   A new user can be created via a `POST` request to `/api/v1/signup`.
*   An existing user can log in via `/api/v1/login` and receive both an access and refresh token.
*   A client can exchange a valid refresh token for a new access token via `/api/v1/auth/refresh`.
*   Sending a request with an invalid/expired access token to a protected endpoint returns a `401 Unauthorized` error.
