# Phase 1, Step 0: Docker Setup

**Goal:** To containerize the Rails application and its dependencies (PostgreSQL, Redis) using Docker. This provides a consistent, isolated, and easy-to-manage development environment.

**Note:** This step should be completed before `01-project-setup.md`. Using Docker changes how some of the commands in that document are run (e.g., `rails` commands must be prefixed with `docker-compose run --rm app`).

---

### Overview

We will create three files in the root of the `heyho-backend` directory:

1.  `Dockerfile`: Instructs Docker on how to build the image for our Rails application.
2.  `docker-compose.yml`: Defines and orchestrates the services needed to run the application (the Rails app, a database, and Redis).
3.  `entrypoint.sh`: A small script to ensure the Rails server starts cleanly inside the container.

---

### 1. The `Dockerfile`

This file builds the Rails application's environment. It uses a multi-stage build to keep the final image size small and efficiently caches gems.

*Create a file named `Dockerfile` with this content:*

```Dockerfile
# Dockerfile

# Use the official Ruby image
FROM ruby:3.2.2-slim-bullseye AS base

# Set environment variables
ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    LANG=C.UTF-8

# Set up dependencies
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# --- Build Stage ---
FROM base AS build

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# --- Final Stage ---
FROM base

# Copy installed gems
COPY --from=build /usr/local/bundle /usr/local/bundle

# Copy application code
COPY . .

# Copy and set permissions for the entrypoint script
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Expose port 3000 and start the Rails server
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
```

---

### 2. The `docker-compose.yml` File

This file tells Docker how to run our multi-service application.

*Create a file named `docker-compose.yml` with this content:*

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    command: rails server -b 0.0.0.0
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis
    environment:
      - DATABASE_URL=postgres://postgres:password@db:5432/heyho_backend_development
      - REDIS_URL=redis://redis:6379/1

  db:
    image: postgres:14-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=password
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
  bundle_cache:
```

---

### 3. The `entrypoint.sh` Script

This script prevents a common Rails error when running in Docker by removing a leftover server PID file.

*Create a file named `entrypoint.sh` with this content:*

```sh
#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
```

---

### How to Use This Setup

1.  **Build the Docker Image:**
    *   This command reads the `Dockerfile` and builds the image for your `app` service.
    ```bash
    docker-compose build
    ```

2.  **Create the Database:**
    *   This command runs `rails db:create` inside a temporary container for the `app` service.
    ```bash
    docker-compose run --rm app rails db:create
    ```

3.  **Run the Application:**
    *   This command starts all services (`app`, `db`, `redis`) in the background.
    ```bash
    docker-compose up
    ```

4.  **Running Other Rails Commands:**
    *   Prefix any `rails` or `rake` command with `docker-compose run --rm app`.
    *   **Migrations:** `docker-compose run --rm app rails db:migrate`
    *   **Console:** `docker-compose run --rm app rails c`
    *   **Tests:** `docker-compose run --rm app bundle exec rspec`

```