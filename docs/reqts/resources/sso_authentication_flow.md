# Social Sign-On (SSO) Authentication Flow

This document outlines the process for allowing users to sign up or log in to `heyho-backend` using third-party identity providers like Google or Firefox, as supported by their respective browsers.

## Overview

Instead of creating a password, a user can delegate authentication to a trusted provider. The flow involves the `browser-extension` obtaining an identity token from the provider and sending it to `heyho-backend`. The backend verifies this token with the provider, finds or creates a corresponding user in its own database, and returns its own standard JWT to the extension for session management.

## Authentication Flow

The process can be broken down into three parts:

### Part 1: Browser Extension Initiates Login

1.  **User Action:** The user clicks a "Sign in with Google" or "Sign in with Firefox" button within the extension's UI.

2.  **Request Provider Token:** The extension calls a browser-specific API to request an OAuth 2.0 identity token from the provider.
    *   **Google Chrome:** The extension will use the `chrome.identity.getAuthToken()` API. This is the most direct method for getting a token that verifies the user's Google identity.
    *   **Mozilla Firefox:** The extension will use the `browser.identity.launchWebAuthFlow()` API to perform a standard OAuth 2.0 authorization flow against Firefox Accounts.

3.  **Send Token to Backend:** The extension receives the `sso_token` from the provider and immediately sends it to the `heyho-backend` in a `POST` request.

### Part 2: `heyho-backend` Verifies and Authenticates

4.  **Receive Provider Token:** The backend receives the request at its dedicated SSO endpoint, for example: `POST /api/v1/auth/sso/google`.
    *   **Request Body:** `{ "sso_token": "<token_from_provider>" }`

5.  **Verify Token with Provider:** The backend makes a secure, server-to-server API call to the provider's token verification endpoint (e.g., Google's `tokeninfo` API).

6.  **Receive User Profile:** The provider validates the token and returns the user's profile, which must include a verified email address and a unique, permanent provider ID (e.g., `google_id`).

7.  **Find or Create User:** The backend queries its own `users` table using the email address from the provider.
    *   **If a user is found:** The backend has successfully identified an existing user.
    *   **If no user is found:** The backend creates a new user record with the email address and associates it with the unique provider ID.

8.  **Issue `heyho-backend` JWT:** Whether the user was found or created, the backend now generates its own standard JWT, containing its own internal `user_id`. This JWT is returned to the extension.
    *   **Success Response:** `{ "token": "<your_own_heyho_backend_jwt>" }`

### Part 3: Extension Manages Session

9.  **Store Session Token:** The extension receives and securely stores the `heyho-backend` JWT.

10. **Authenticated Operations:** All subsequent requests to the `heyho-backend` (for syncing data, etc.) are authenticated using this `heyho-backend` JWT in the `Authorization` header. The provider's `sso_token` is now discarded and is not used again until the next login.
