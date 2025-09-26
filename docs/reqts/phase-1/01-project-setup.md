# Phase 1, Step 1: Project Setup (Docker-based)

**Goal:** Initialize a new Rails 7+ application for the `heyho-sync-be`, configure it for a PostgreSQL database using Docker containers, and set up comprehensive testing and code quality infrastructure.

---

### Prerequisites

- Docker Desktop installed and running
- Git installed
- Make command available (pre-installed on macOS/Linux)

### Step-by-Step Implementation

1. **Clone and Build Docker Environment:**
    * Clone the repository and build the Docker containers.

    ```bash
    git clone https://github.com/gabrielbrrll/heyho-sync-be.git
    cd heyho-sync-be
    make build
    ```

2. **Initialize Rails Application (Inside Docker):**
    * Generate a new Rails API-only application within the Docker container.
    * The `--force` flag overwrites the existing Gemfile.
    * The `--skip-bundle` flag prevents local bundle installation.

    ```bash
    docker-compose run --rm app rails new . \
      --api \
      --database=postgresql \
      --force \
      --skip-bundle \
      --skip-git
    ```

3. **Update Gemfile for Development:**
    * The Gemfile already includes necessary gems, but ensure these are present:

    ```ruby
    # Gemfile
    group :development, :test do
      gem 'debug', platforms: %i[mri windows]
      gem 'rspec-rails', '~> 6.0'

      # Code quality tools (already configured)
      gem 'rubocop', '~> 1.56', require: false
      gem 'rubocop-performance', '~> 1.19', require: false
      gem 'rubocop-rails', '~> 2.21', require: false
      gem 'rubocop-rspec', '~> 2.24', require: false

      # Security scanning
      gem 'brakeman', '~> 6.0', require: false

      # Documentation
      gem 'yard', '~> 0.9', require: false
    end
    ```

4. **Configure Database (Docker-based):**
    * Update `config/database.yml` to use Docker service names:

    ```yaml
    default: &default
      adapter: postgresql
      encoding: unicode
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      host: <%= ENV.fetch("DATABASE_HOST", "db") %>
      username: <%= ENV.fetch("DATABASE_USER", "postgres") %>
      password: <%= ENV.fetch("DATABASE_PASSWORD", "postgres") %>

    development:
      <<: *default
      database: heyho_sync_development

    test:
      <<: *default
      database: heyho_sync_test

    production:
      <<: *default
      database: heyho_sync_production
      username: <%= ENV["DATABASE_USER"] %>
      password: <%= ENV["DATABASE_PASSWORD"] %>
    ```

5. **Install Dependencies and Create Database:**
    * Install gems and create the database using Docker commands:

    ```bash
    # Install gems in Docker
    make bundle

    # Create and setup databases
    make db-create
    make migrate
    ```

6. **Set Up Testing Framework (RSpec):**
    * Install RSpec within the Docker container:

    ```bash
    docker-compose run --rm app rails generate rspec:install
    ```

    * Configure RSpec for Docker in `spec/rails_helper.rb`:
    ```ruby
    # Add to spec/rails_helper.rb
    RSpec.configure do |config|
      # Database cleaner configuration for Docker
      config.before(:suite) do
        DatabaseCleaner.strategy = :transaction
        DatabaseCleaner.clean_with(:truncation)
      end
    end
    ```

7. **Verify Docker Services:**
    * Start all services and verify they're running:

    ```bash
    # Start services
    make up

    # In another terminal, check services
    docker-compose ps
    ```

    You should see:
    - `heyho-sync-be-app-1` (Rails application)
    - `heyho-sync-be-db-1` (PostgreSQL)
    - `heyho-sync-be-redis-1` (Redis cache)

8. **Run Quality Checks:**
    * Verify all code quality tools are working:

    ```bash
    # Run linter
    make lint

    # Run tests
    make test

    # Run security scan (will skip until Rails is initialized)
    make security-check

    # Run all quality checks
    make quality-check
    ```

9. **Test Git Hooks:**
    * Verify pre-commit hooks are working:

    ```bash
    # Test hooks manually
    make hooks-test

    # Create a test file and commit
    echo "class Test; end" > test.rb
    git add test.rb
    git commit -m "test: verify hooks"
    # Should run RuboCop and block if issues found
    ```

### Docker-Specific Commands

All Rails commands run inside Docker containers:

```bash
# Rails console
make console

# Rails generators
make generate ARGS="controller Api::V1::Health"

# Database operations
make migrate       # Run migrations
make db-reset     # Drop, create, migrate, seed

# View logs
make logs         # All services
make logs-app     # Just Rails

# Shell access
make shell        # Bash prompt in container
```

### Project Structure

```
heyho-sync-be/
├── .github/
│   └── workflows/
│       └── quality-checks.yml    # CI/CD pipeline
├── .vscode/
│   └── tasks.json               # VS Code/Cursor tasks
├── app/                         # Rails application (after initialization)
├── config/                      # Rails configuration
├── db/                         # Database files
├── scripts/
│   └── pre-commit.sh           # Docker-based git hooks
├── specs/
│   ├── phase-1/                # Implementation specs
│   └── tools/                  # Documentation
├── .rubocop.yml                # RuboCop configuration
├── .yardopts                   # YARD documentation config
├── docker-compose.yml          # Container orchestration
├── Dockerfile                  # Rails container definition
├── Gemfile                     # Ruby dependencies
├── Gemfile.lock               # Locked versions
└── Makefile                   # Docker command shortcuts
```

### Acceptance Criteria

* **Docker services start successfully:**
  ```bash
  make up
  # All three containers should be running
  ```

* **Rails server is accessible:**
  ```bash
  # Visit http://localhost:3000
  # Should see Rails welcome or API response
  ```

* **Database connection works:**
  ```bash
  docker-compose run --rm app rails db:version
  # Should output: Current version: [timestamp]
  ```

* **Tests run successfully:**
  ```bash
  make test
  # Should run without errors (0 examples initially)
  ```

* **Code quality checks pass:**
  ```bash
  make lint
  # Should show: "no offenses detected"
  ```

* **Git hooks work:**
  ```bash
  make hooks-test
  # Should output: "✅ All pre-commit checks passed!"
  ```

### Advantages of Docker Setup

1. **Consistency**: Same environment for all developers
2. **No Local Dependencies**: No need to install Ruby, PostgreSQL, or Redis locally
3. **Isolation**: Multiple projects with different Ruby versions can coexist
4. **Easy Onboarding**: New developers just run `make build`
5. **Production Parity**: Development environment matches production
6. **Clean Uninstall**: Just delete the directory and Docker images

### Troubleshooting

**If containers won't start:**
```bash
# Check Docker is running
docker info

# Rebuild if needed
make build

# Check logs
make logs
```

**If database connection fails:**
```bash
# Ensure db container is running
docker-compose ps

# Recreate database
make db-reset
```

**If gems are missing:**
```bash
# Reinstall dependencies
make bundle

# Rebuild container
make build
```

### Next Steps

Once the Rails application is initialized:
1. Create API versioning structure (`app/controllers/api/v1/`)
2. Set up user authentication (Phase 1, Step 2)
3. Configure CORS for frontend access
4. Set up background job processing with Sidekiq/Redis