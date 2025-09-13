# Docker Setup Guide

This guide explains the Docker-based development environment for the HeyHo Sync Backend project.

## Overview

The entire development environment runs in Docker containers, ensuring consistency across all developer machines and eliminating "works on my machine" issues.

## Architecture

```
┌─────────────────────────────────────────────┐
│           Host Machine (Your Computer)        │
│                                               │
│  ┌─────────────────────────────────────────┐ │
│  │         Docker Desktop                   │ │
│  │                                          │ │
│  │  ┌──────────┐  ┌──────────┐  ┌────────┐│ │
│  │  │   app    │  │    db    │  │ redis  ││ │
│  │  │ Rails    │──│PostgreSQL│──│ Cache  ││ │
│  │  │Container │  │Container │  │Container││ │
│  │  └──────────┘  └──────────┘  └────────┘│ │
│  │                                          │ │
│  │  All connected via Docker Network        │ │
│  └─────────────────────────────────────────┘ │
│                                               │
│  Your code (mounted as volume) ──────────────┘
└─────────────────────────────────────────────┘
```

## Container Details

### 1. App Container (Rails)
- **Base Image**: `ruby:3.2.0-slim-bullseye`
- **Purpose**: Runs the Rails application
- **Exposed Port**: 3000
- **Volume Mounts**:
  - Your code directory → `/app` (for live code reloading)
- **Installed Tools**:
  - Ruby 3.2.0
  - Rails 7.0
  - RuboCop, Brakeman, YARD
  - All gems from Gemfile

### 2. Database Container (PostgreSQL)
- **Image**: `postgres:15`
- **Purpose**: Database server
- **Port**: 5432 (mapped to host)
- **Credentials**:
  - User: `postgres`
  - Password: `postgres`
  - Database: `heyho_sync_development`
- **Volume**: Persistent data storage

### 3. Redis Container
- **Image**: `redis:7-alpine`
- **Purpose**: Cache and background job queue
- **Port**: 6379 (mapped to host)

## File Structure

```
heyho-sync-be/
├── docker-compose.yml      # Container orchestration
├── Dockerfile             # Rails app container definition
├── entrypoint.sh         # Container startup script
├── Gemfile               # Ruby dependencies
├── Gemfile.lock          # Locked dependency versions
├── Makefile              # Docker command shortcuts
└── scripts/
    └── pre-commit.sh     # Git hook that runs in Docker
```

## How It Works

### 1. Building the Environment
```bash
make build
```
This command:
1. Reads the `Dockerfile`
2. Creates a Ruby 3.2.0 container
3. Installs system dependencies (PostgreSQL client, build tools)
4. Copies Gemfile and installs all Ruby gems
5. Sets up the working directory

### 2. Starting Services
```bash
make up
```
This command:
1. Starts PostgreSQL container
2. Starts Redis container
3. Starts Rails app container
4. Mounts your local code into the container
5. Runs the Rails server on port 3000

### 3. Running Commands
All commands run inside Docker:
```bash
make console     # Opens Rails console in container
make lint        # Runs RuboCop in container
make test        # Runs tests in container
make shell       # Opens bash shell in container
```

## Development Workflow

### Making Code Changes
1. Edit files locally in your IDE (Cursor/VS Code)
2. Changes are immediately reflected in the container (via volume mount)
3. Rails auto-reloads changed files (no container restart needed)

### Adding Gems
1. Edit `Gemfile`
2. Run `make bundle` to install in container
3. Commit both `Gemfile` and `Gemfile.lock`

### Database Operations
```bash
make migrate     # Run migrations
make db-reset    # Drop, create, migrate, seed
make db-create   # Create database
```

### Debugging
```bash
# View logs
make logs        # All containers
make logs-app    # Just Rails logs

# Access container shell
make shell       # Bash prompt inside container
> rails routes   # Run any command inside container
```

## Git Hooks Integration

The pre-commit hook (`scripts/pre-commit.sh`) runs RuboCop inside Docker:
1. When you `git commit`, the hook triggers
2. It starts a temporary Docker container
3. Runs RuboCop on your staged files
4. Blocks commit if issues found

## Environment Variables

### Development (docker-compose.yml)
```yaml
environment:
  RAILS_ENV: development
  DATABASE_URL: postgres://postgres:postgres@db:5432/heyho_sync_development
  REDIS_URL: redis://redis:6379/0
```

### Production Considerations
- Use environment-specific docker-compose files
- Store secrets in `.env` files (never commit these)
- Use Docker secrets or orchestration tools

## Common Docker Commands

### Container Management
```bash
docker-compose ps                    # List running containers
docker-compose logs -f app           # Follow app logs
docker-compose exec app bash         # Shell into running container
docker-compose down                  # Stop all containers
docker-compose down -v               # Stop and remove volumes
```

### Debugging
```bash
docker-compose exec app rails c      # Rails console
docker-compose exec db psql -U postgres  # PostgreSQL console
docker-compose exec redis redis-cli  # Redis console
```

### Cleanup
```bash
docker system prune -a               # Remove unused images
docker volume prune                  # Remove unused volumes
make clean                          # Project-specific cleanup
```

## Benefits of Docker Setup

1. **Consistency**: Same environment for all developers
2. **Isolation**: No conflicts with system Ruby/gems
3. **Easy Onboarding**: New developers just run `make build`
4. **Version Control**: Ruby version locked in Dockerfile
5. **Clean System**: No global gem pollution
6. **Multiple Projects**: Each project has isolated dependencies
7. **CI/CD Parity**: Same Docker image in development and production

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker-compose logs app

# Rebuild if Gemfile changed
make build
```

### Permission Issues
```bash
# Fix ownership (if needed)
docker-compose exec app chown -R $(id -u):$(id -g) .
```

### Port Already in Use
```bash
# Find what's using port 3000
lsof -i :3000

# Or change port in docker-compose.yml
ports:
  - "3001:3000"  # Use 3001 on host
```

### Slow Performance (macOS)
Docker Desktop on macOS can be slow with file syncing. Options:
1. Use cached volumes in docker-compose.yml
2. Exclude node_modules and tmp from sync
3. Consider using Docker Desktop's virtualization settings

### Can't Connect to Database
```bash
# Ensure db container is running
docker-compose ps

# Check database logs
docker-compose logs db

# Recreate database
make db-reset
```

## Best Practices

1. **Always use Make commands** - They ensure correct Docker context
2. **Commit Gemfile.lock** - Ensures same gems for all developers
3. **Don't install gems locally** - Use `make bundle` instead
4. **Check Docker status** - Ensure Docker Desktop is running
5. **Use .dockerignore** - Exclude unnecessary files from build
6. **Regular cleanup** - Run `docker system prune` periodically

## Next Steps

Once you initialize the Rails application:
```bash
# Initialize Rails app
docker-compose run --rm app rails new . --force --database=postgresql --skip-bundle

# Run setup
make setup

# Start developing!
make up
```

The Docker environment is ready for full Rails development!