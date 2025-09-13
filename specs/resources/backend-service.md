# Browser Extension Backend Service

## 1. Overview

This backend service is the central data and authentication hub for the [Your Browser Extension Name]. Its primary responsibilities are:

1.  **Data Ingestion & Processing**: To collect, process, and securely store user browsing data sent from the browser extension.
2.  **User Authentication**: To manage user identity, including logins via email/password and Single Sign-On (SSO).
3.  **Data Federation**: To act as a central platform, exposing user data to other approved applications through a secure, permission-based API.

---

## 2. Core Architectural Principles

*   **Standalone Service**: `heyho-backend` is a self-contained service with its own user database and authentication system.
*   **Client-Side Data Buffering**: The backend does not accept or store any data for anonymous users. The browser extension is responsible for buffering all data locally until a user is authenticated.
*   **Stateless Authentication (JWT)**: The service uses a two-token system (Access and Refresh JWTs) for authenticating requests, as detailed in `session_management.md`.
*   **Delegated Authorization (OAuth 2.0)**: To share data with third-party applications, the service can act as an OAuth 2.0 provider, allowing users to grant specific, revocable permissions to other apps.

---

## 3. API Endpoints

### Authentication Endpoints

These endpoints are for managing user identity.

#### `POST /api/v1/auth/login`
*   **Description**: Authenticates a user with email and password.
*   **Request Body**: `{ "email": "user@example.com", "password": "password123" }`
*   **Success Response**: `{ "access_token": "<JWT>", "refresh_token": "<JWT>" }`

#### `POST /api/v1/auth/sso/:provider` (e.g., `/auth/sso/google`)
*   **Description**: Authenticates or signs up a user via an SSO provider.
*   **Request Body**: `{ "sso_token": "<Provider_Token>" }`
*   **Success Response**: `{ "access_token": "<JWT>", "refresh_token": "<JWT>" }`

#### `POST /api/v1/auth/refresh`
*   **Description**: Issues a new access token in exchange for a valid refresh token.
*   **Request Body**: `{ "refresh_token": "<Refresh_Token>" }`
*   **Success Response**: `{ "access_token": "<JWT>", "refresh_token": "<JWT>" }`

### Data Sync Endpoint

#### `POST /api/v1/data/sync`
*   **Description**: Receives batches of browsing data from an authenticated client.
*   **Authentication**: **Required (Access Token)**.
*   **Request Body**: `{ "pageVisits": [...], "tabAggregates": [...] }`
*   **Success Response**: `200 OK`

### Data Access Endpoints

These endpoints provide access to the processed user data.

#### `GET /api/v1/insights`
*   **Description**: Retrieves personalized insights for the authenticated user.
*   **Authentication**: **Required (Access Token)**.
*   **Success Response**: `{ "insights": [...] }`

#### `GET /api/v1/activity/summary`
*   **Description**: Retrieves a summary of the user's recent activity.
*   **Authentication**: **Required (Access Token)**.
*   **Query Parameters**: `?period=weekly`
*   **Success Response**: `{ "summary": { ... } }`

---

## 4. Setup and Local Development

### Prerequisites
*   Node.js (v18.x or later)
*   PostgreSQL (or other specified database)
*   npm or yarn

### Installation
1.  Clone the repository.
2.  Install dependencies:
    ```bash
    npm install
    ```

### Configuration
Create a `.env` file in the root of the project and add the following environment variables:

```
# Server Configuration
PORT=3000

# Database Connection
DATABASE_URL="postgresql://user:password@localhost:5432/mydatabase"

# JWT Configuration
JWT_SECRET="your-super-secret-and-long-jwt-secret"
JWT_EXPIRES_IN="15m" # Access Token Expiration
JWT_REFRESH_EXPIRES_IN="30d" # Refresh Token Expiration

# OAuth 2.0 Configuration (for when you act as a provider)
# Add client IDs and secrets for approved third-party apps here
```

### Running the Server
*   **Development**: `npm run dev`
*   **Production**: `npm start`

### Running Tests
```bash
npm test
```
