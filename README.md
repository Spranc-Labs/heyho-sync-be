# HeyHo Sync Backend

A robust Ruby on Rails backend application with comprehensive code quality tools integration, fully containerized with Docker for consistent development environments.

## Setup

### Prerequisites
- Docker Desktop (includes Docker and Docker Compose)
- Git
- Make (usually pre-installed on macOS/Linux)

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/gabrielbrrll/heyho-sync-be.git
cd heyho-sync-be

# Build Docker images
make build

# Once Rails is initialized, run full setup
# make setup  # This will create DB, run migrations, and start services

# Verify git hooks are working
make hooks-test
```

### Docker Architecture
- **app**: Ruby on Rails application container
- **db**: PostgreSQL database container
- **redis**: Redis cache/queue container
- All dependencies are containerized - no local Ruby installation needed

## Development Workflow

### Starting the Application
```bash
# Start all services
make up

# Start in detached mode
make upd

# Stop services
make down
```

### Code Quality Tools

#### Linting
```bash
# Check code style
make lint

# Auto-fix style issues
make lint-fix

# Generate TODO file for existing violations
make rubocop-todo
```

#### Security Scanning
```bash
# Run security scan
make security-check

# Generate detailed HTML report
make security-report

# Interactive mode for reviewing issues
make security-interactive
```

#### Documentation
```bash
# Generate documentation
make docs

# Serve documentation locally (http://localhost:8808)
make docs-serve

# Check documentation coverage
make docs-stats
```

#### Quality Check
```bash
# Run all quality checks (lint, security, tests)
make quality-check
```

### Git Hooks Management
```bash
# Check hooks status
make hooks-install

# Test pre-commit hook manually
make hooks-test
```

**Note**: Git hooks run RuboCop checks inside Docker containers automatically on commit.

### Database Operations
```bash
# Run migrations
make migrate

# Reset database
make db-reset

# Open Rails console
make console
```

### Testing
```bash
# Run all tests
make test
```

## Code Quality Standards

### RuboCop
- Line length: 120 characters
- Indentation: 2 spaces
- String literals: single quotes
- String interpolation: double quotes

### Brakeman Security
- Scans for OWASP Top 10 vulnerabilities
- SQL injection detection
- XSS prevention checks
- Mass assignment protection

### Documentation (YARD)
- All public methods must be documented
- Include parameter types and descriptions
- Provide usage examples for complex methods

### Git Hooks (Docker-based)
- **Pre-commit**: Runs RuboCop on staged Ruby files via Docker
- Automatically blocks commits with style violations
- No local Ruby installation required

## Conventional Commit Format
```
<type>(<scope>): <subject>

Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
```

Example:
```
feat(auth): add JWT authentication
fix(sync): resolve race condition in data synchronization
```

## Available Make Commands
Run `make help` to see all available commands.

### Most Common Commands
- `make build` - Build Docker images
- `make up` - Start all services
- `make down` - Stop all services
- `make lint` - Run RuboCop
- `make test` - Run tests
- `make console` - Rails console
- `make shell` - Bash shell in container

## CI/CD
GitHub Actions automatically runs:
- RuboCop linting
- Brakeman security scanning
- RSpec test suite
- Documentation coverage check

## Documentation
- [Docker Setup Guide](specs/tools/docker-setup-guide.md)
- [Code Quality Tools Guide](specs/tools/code-quality-tools.md)

## Troubleshooting

### Docker Issues
```bash
# Rebuild containers after Gemfile changes
make build

# Clean up containers and volumes
make clean

# View logs
make logs       # All services
make logs-app   # Just Rails app
```

### Bundle Installation Issues
```bash
# Install gems inside Docker
make bundle
```

### Git Hooks Not Running
```bash
# Ensure Docker is running
docker info

# Test hooks manually
make hooks-test
```

### Port Conflicts
If port 3000 is already in use:
```bash
# Stop conflicting service or change port in docker-compose.yml
lsof -i :3000  # Find what's using port 3000
```

### Container Access
```bash
# Open bash shell in app container
make shell

# Open Rails console
make console
```

### Security False Positives
Review and update `config/brakeman.ignore` after careful analysis.

## License
[Your License Here]