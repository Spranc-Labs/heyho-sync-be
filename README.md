# HeyHo Sync Backend

A Rails API application for HeyHo Sync, built with Docker and supporting multiple environments (development, staging, production).

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Git
- Make (optional, for using Makefile commands)

### Initial Setup

1. Clone the repository:
```bash
git clone https://github.com/gabrielbrrll/heyho-sync-be.git
cd heyho-sync-be
```

2. Setup environment files:
```bash
make env-setup
# Or manually:
cp config/env/.env.example config/env/.env.development
```

3. Update `config/env/.env.development` with your configuration

4. Build and start the application:
```bash
make setup
# Or manually:
docker-compose build
docker-compose run --rm app bundle exec rails db:create db:migrate
docker-compose up
```

The application will be available at `http://localhost:3000`

## 📋 Available Make Commands

### Basic Operations
```bash
make help          # Show all available commands
make up            # Start all services
make down          # Stop all services
make logs          # Show logs
make shell         # Open bash shell in app container
make console       # Open Rails console
```

### Environment Management
```bash
# Development
make dev           # Start development environment
make dev-down      # Stop development environment
make dev-logs      # Show development logs
make dev-console   # Open Rails console in development

# Staging
make staging       # Start staging environment
make staging-down  # Stop staging environment
make staging-logs  # Show staging logs

# Production (with confirmation prompts)
make prod          # Start production environment
make prod-down     # Stop production environment
make prod-console  # Open Rails console in production (careful!)
```

### Database Operations
```bash
make migrate       # Run database migrations
make seed          # Seed the database
make db-reset      # Reset database (drop, create, migrate, seed)
```

### Code Quality
```bash
make test          # Run tests
make lint          # Run RuboCop linter
make lint-fix      # Auto-fix RuboCop violations
make security-check # Run Brakeman security scanner
make quality-check # Run all quality checks
```

## 🌍 Environment Configuration

This application supports three environments:
- **Development**: Local development with debug tools
- **Staging**: Production-like environment for testing
- **Production**: Live production environment

### Setting Up Environments

1. Copy the example environment file:
```bash
cp config/env/.env.example config/env/.env.development
cp config/env/.env.example config/env/.env.staging
cp config/env/.env.example config/env/.env.production
```

2. Update each file with environment-specific values

3. Use the `bin/docker-env` script or Make commands to run different environments:
```bash
# Using bin/docker-env
./bin/docker-env development up
./bin/docker-env staging up
./bin/docker-env production up

# Using Make
make dev
make staging
make prod
```

For detailed environment setup, see [ENVIRONMENT_SETUP.md](specs/resources/environment_setup.md)

## 🏗️ Project Structure

```
.
├── app/                    # Rails application code
│   ├── controllers/        # API controllers
│   ├── models/            # ActiveRecord models
│   ├── jobs/              # Background jobs
│   └── mailers/           # Email mailers
├── config/                # Configuration files
│   ├── env/               # Environment variable files
│   ├── environments/      # Environment-specific configs
│   ├── database.yml       # Database configuration
│   └── routes.rb          # API routes
├── db/                    # Database files
│   ├── migrate/           # Database migrations
│   └── seeds.rb           # Seed data
├── spec/                  # RSpec tests
├── bin/                   # Executable scripts
│   └── docker-env         # Environment management script
├── docker-compose.yml     # Main Docker Compose configuration
├── docker-compose.*.yml   # Environment-specific overrides
├── Dockerfile             # Docker image definition
├── Makefile              # Make commands
└── Gemfile               # Ruby dependencies
```

## 🛠️ Technology Stack

- **Framework**: Rails 7.0.8 (API-only mode)
- **Language**: Ruby 3.2.0
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7
- **Web Server**: Puma
- **Containerization**: Docker & Docker Compose

### Key Gems
- **Testing**: RSpec, FactoryBot, Shoulda Matchers
- **Code Quality**: RuboCop (with Rails/RSpec extensions)
- **Security**: Brakeman
- **Documentation**: YARD
- **Environment**: dotenv-rails

## 🧪 Testing

Run the test suite:
```bash
make test
# Or
docker-compose run --rm app bundle exec rspec
```

## 📝 Code Style

This project uses RuboCop for code linting:
```bash
make lint         # Check for issues
make lint-fix     # Auto-fix issues
```

## 🔒 Security

Run security checks with Brakeman:
```bash
make security-check           # Quick security scan
make security-report          # Generate detailed HTML report
```

## 🚢 Deployment

### Staging Deployment
1. Update `config/env/.env.staging` with your staging configuration
2. Build and deploy:
```bash
make staging
```

### Production Deployment
1. Update `config/env/.env.production` with your production configuration
2. Build and deploy (with confirmation):
```bash
make prod
```

**Note**: In production, consider using:
- Managed database services (AWS RDS, Google Cloud SQL, etc.)
- Container orchestration (Kubernetes, ECS, etc.)
- CI/CD pipelines for automated deployments

## 📚 Documentation

- [Environment Setup Guide](specs/resources/environment_setup.md) - Detailed environment configuration
- [API Documentation](docs/api.md) - API endpoints and usage (if applicable)

Generate code documentation:
```bash
make docs         # Generate YARD documentation
make docs-serve   # Serve documentation locally
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is private and proprietary.

## 👥 Team

- Gabriel O'Campo - Initial work

## 🆘 Troubleshooting

### Common Issues

**Docker containers won't start**
```bash
make clean        # Clean up everything
make setup        # Rebuild from scratch
```

**Database connection errors**
```bash
make db-reset     # Reset the database
```

**Port already in use**
- Change the port in `docker-compose.yml` or stop the conflicting service

For more help, check the logs:
```bash
make logs         # All services
make logs-app     # Just the app
```