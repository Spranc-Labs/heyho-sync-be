# Standalone Authentication and Data Sync Strategy

This document outlines the authentication and data synchronization flow for `heyho-backend`, operating as a self-contained service.

## Guiding Principle

**`heyho-backend` is a standalone service with its own user database and authentication system.** It only ever stores data associated with a valid, authenticated user. It does not store any anonymous data.

## Data Synchronization Flow

This flow relies on the `browser-extension` to buffer data locally until a user is authenticated.

1.  **Data Collection & Local Buffering**:
    *   The `browser-extension` is responsible for collecting all browsing activity (e.g., `pageVisits`).
    *   This data is stored **locally** within the browser's own storage (`browser.storage.local` or a more robust solution like IndexedDB).

2.  **User Authentication**:
    *   The user signs up or logs in via the `browser-extension` UI.
    *   The extension sends credentials to `heyho-backend`'s `/api/v1/auth/login` endpoint.
    *   `heyho-backend` validates the credentials and returns its own **JWT**.
    *   The extension securely stores this JWT. The presence of this token enables synchronization.

3.  **Periodic Sync Process**:
    *   A background process in the `browser-extension` runs on a set interval.
    *   On each interval, it checks for the presence of the `heyho-backend` JWT.
        *   **If no token exists**, the process terminates. The data remains in the local buffer.
        *   **If a token exists**, the process continues.

4.  **Data Transmission and Clearing**:
    *   The extension gathers the data from its local buffer.
    *   It sends the batch of data to a single, authenticated endpoint (e.g., `POST /api/v1/data/sync`), including the JWT in the `Authorization` header.
    *   `heyho-backend` validates the JWT, identifies the user, and ingests the data.
    *   **Upon a successful `200 OK` response**, the `browser-extension` is responsible for clearing the data from its local buffer that was just successfully synced.

## Impact on Development

*   **Backend (`heyho-backend`)**: The backend is simplified. It does not need endpoints for anonymous data or a "claiming" process. It only requires a single, authenticated endpoint for accepting batches of data.
*   **Client (`browser-extension`)**: The complexity shifts to the client. The extension must implement a robust local storage/buffering system, handle data serialization, and manage the logic for clearing the buffer after a successful sync.
