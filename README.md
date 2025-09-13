# HeyHo Sync Backend

A robust Ruby on Rails backend application with comprehensive code quality tools integration.

## Setup

### Prerequisites
- Docker and Docker Compose
- Git

### Initial Setup
```bash
# Clone the repository
git clone <repository-url>
cd heyho-sync-be

# Build and setup the application
make setup

# Install git hooks
make hooks-install
```

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
# Install hooks
make hooks-install

# Uninstall hooks
make hooks-uninstall

# Run hooks manually
make hooks-run HOOK=pre-commit
```

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

### Git Hooks (Lefthook)
- **Pre-commit**: RuboCop, RSpec, debugger detection
- **Pre-push**: Full test suite, security scan
- **Commit-msg**: Conventional commit format

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

## CI/CD
GitHub Actions automatically runs:
- RuboCop linting
- Brakeman security scanning
- RSpec test suite
- Documentation coverage check

## Documentation
- [Code Quality Tools Guide](specs/tools/code-quality-tools.md)

## Troubleshooting

### Bundle Installation Issues
```bash
make bundle
```

### Git Hooks Not Running
```bash
make hooks-uninstall
make hooks-install
```

### Security False Positives
Review and update `config/brakeman.ignore` after careful analysis.

## License
[Your License Here]