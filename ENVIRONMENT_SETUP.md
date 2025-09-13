# Environment Setup Guide

This application supports multiple environments: development, staging, and production.

## Environment Configuration

### 1. Setting Up Environment Variables

Each environment has its own `.env` file:
- `.env.development` - Local development settings
- `.env.staging` - Staging environment settings
- `.env.production` - Production environment settings

**Important:** Never commit actual credentials to git. The `.env.*` files (except `.env.example`) are gitignored.

### 2. Initial Setup

1. Copy the example environment file for your environment:
   ```bash
   cp .env.example .env.development
   ```

2. Update the values in your `.env.development` file with your actual configuration.

3. For staging/production, create appropriate `.env` files:
   ```bash
   cp .env.example .env.staging
   cp .env.example .env.production
   ```

### 3. Running Different Environments

#### Using the Helper Script

We provide a `bin/docker-env` script to easily manage different environments:

```bash
# Development (default)
./bin/docker-env development up
./bin/docker-env dev up -d  # Run in background

# Staging
./bin/docker-env staging up
./bin/docker-env stg down

# Production (will ask for confirmation)
./bin/docker-env production up
./bin/docker-env prod logs app
```

#### Manual Docker Compose Commands

```bash
# Development
docker-compose up

# Staging
RAILS_ENV=staging docker-compose -f docker-compose.yml -f docker-compose.staging.yml up

# Production
RAILS_ENV=production docker-compose -f docker-compose.yml -f docker-compose.production.yml up
```

## Environment-Specific Configuration

### Development
- Full source code mounted
- Debug logging enabled
- All ports exposed
- No SSL enforcement

### Staging
- Similar to production but with more verbose logging
- SSL optional (configurable via FORCE_SSL env var)
- Useful for testing production-like deployments

### Production
- No source code mounting
- Minimal logging
- SSL enforced (configurable)
- Resource limits applied
- No database/Redis ports exposed externally

## Key Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_HOST` | PostgreSQL host | `db` (Docker service name) |
| `DATABASE_USER` | Database username | `postgres` |
| `DATABASE_PASSWORD` | Database password | `postgres` (change in production!) |
| `DATABASE_NAME` | Database name | `heyho_sync_[environment]` |
| `REDIS_URL` | Redis connection URL | `redis://redis:6379/1` |
| `RAILS_ENV` | Rails environment | `development` |
| `RAILS_MASTER_KEY` | Master key for credentials | Required in staging/production |
| `SECRET_KEY_BASE` | Secret key base | Required in staging/production |
| `FORCE_SSL` | Enable SSL enforcement | `false` (true in production) |

## Security Best Practices

1. **Never commit secrets**: All `.env` files with actual values are gitignored
2. **Use strong passwords**: Generate secure passwords for production
3. **Rotate credentials regularly**: Update passwords and keys periodically
4. **Use environment-specific keys**: Don't reuse the same RAILS_MASTER_KEY across environments
5. **Secure your production environment**: Use managed database services, SSL certificates, and proper firewall rules

## Generating Secret Keys

```bash
# Generate a new secret key base
docker-compose run --rm app rails secret

# Generate a new master key (if needed)
docker-compose run --rm app rails credentials:edit
```

## Database Management

```bash
# Create database
./bin/docker-env development run --rm app rails db:create

# Run migrations
./bin/docker-env development run --rm app rails db:migrate

# Seed database (development only)
./bin/docker-env development run --rm app rails db:seed

# Reset database (development only)
./bin/docker-env development run --rm app rails db:reset
```

## Troubleshooting

### Environment variables not loading
- Ensure your `.env.[environment]` file exists
- Check file permissions
- Restart Docker containers after changing env files

### Database connection issues
- Verify DATABASE_HOST is correct
- Check if database container is running: `docker-compose ps`
- Ensure database credentials match in both app and db services

### Port conflicts
- Change the port mapping in docker-compose.yml
- Or stop conflicting services