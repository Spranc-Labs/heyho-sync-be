# Session Management and Token Refresh Strategy

This document outlines the strategy for managing user sessions to provide a persistent, long-term login experience while maintaining high security. This is achieved using a two-token system: a short-lived Access Token and a long-lived Refresh Token.

## Core Concepts

To avoid forcing users to log in repeatedly, we will issue two distinct types of tokens upon a successful authentication.

### 1. Access Token (JWT)
*   **Purpose**: To authorize access to protected API endpoints (e.g., syncing data, fetching insights).
*   **Type**: Standard JSON Web Token (JWT) containing user claims.
*   **Lifespan**: **Short** (e.g., 15 minutes). This short lifespan minimizes the risk if the token is ever compromised.
*   **Usage**: Sent with every API request in the `Authorization: Bearer <token>` header.

### 2. Refresh Token
*   **Purpose**: To obtain a new Access Token when the current one expires. It cannot be used to access data endpoints directly.
*   **Type**: A secure, randomly generated string stored in the backend database, associated with a user and device.
*   **Lifespan**: **Long** (e.g., 30-90 days).
*   **Usage**: Sent only to the dedicated token refresh endpoint.

## The Seamless Refresh Flow

This entire flow is designed to be handled automatically by the client (`browser-extension`) without any user interaction.

1.  **Initial Authentication**
    *   A user logs in via password or SSO.
    *   The `heyho-backend` validates the credentials and generates **both** an `access_token` and a `refresh_token`.
    *   **Response:** `{ "access_token": "...", "refresh_token": "..." }`
    *   The `browser-extension` securely stores both tokens.

2.  **Authenticated API Calls**
    *   The extension uses the `access_token` to make API calls. The server validates the token and responds as normal.

3.  **Handling an Expired Access Token**
    *   Eventually, the `access_token` expires. The extension attempts to make an API call with the expired token.
    *   The backend rejects this request with a `401 Unauthorized` status code.

4.  **Automatic Token Refresh**
    *   The extension's API client is built to automatically intercept any `401` response.
    *   Upon catching a `401`, it immediately makes a `POST` request to the refresh endpoint, sending the long-lived `refresh_token`.
    *   **Endpoint:** `POST /api/v1/auth/refresh`
    *   **Request Body:** `{ "refresh_token": "<the_long_lived_token>" }`

5.  **Backend Issues New Tokens**
    *   The backend receives the `refresh_token`, looks it up in its database to ensure it is valid and has not been revoked.
    *   If valid, the backend generates a **new** `access_token` (and optionally, a new `refresh_token` for security rotation).
    *   It invalidates the used `refresh_token` and returns the new tokens to the client.
    *   **Response:** `{ "access_token": "...", "refresh_token": "..." }`

6.  **Retry Original Request**
    *   The extension updates its stored tokens with the new ones.
    *   It then automatically retries the original API call that failed (e.g., the data sync). This time, the request succeeds with the new `access_token`.

## Benefits of this Approach

*   **Enhanced Security**: The frequent expiration of the Access Token significantly limits the window of opportunity for an attacker if a token is intercepted.
*   **Seamless User Experience**: The user remains logged in for the lifespan of the Refresh Token (weeks or months) without ever needing to re-authenticate manually.
*   **Full Control**: A user's session can be remotely invalidated at any time by revoking their Refresh Tokens in the backend database.
