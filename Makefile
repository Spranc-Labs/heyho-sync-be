.PHONY: help setup build up down restart logs console migrate seed test test-auth test-users test-verification test-requests test-models test-fast test-coverage test-ci clean db-create db-drop db-reset shell lint lint-fix security-check docs quality-check pre-commit-check hooks-install hooks-test docs-serve docs-stats rubocop-todo security-report security-interactive dev staging prod dev-up dev-down dev-logs staging-up staging-down staging-logs prod-up prod-down prod-logs env-setup env-check

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Initial setup - build, create db, migrate, and start
	docker-compose build
	docker-compose run --rm app bundle exec rails db:create
	docker-compose run --rm app bundle exec rails db:migrate
	docker-compose up

build: ## Build Docker images
	docker-compose build

up: ## Start all services
	docker-compose up

upd: ## Start all services in detached mode
	docker-compose up -d

down: ## Stop all services
	docker-compose down

restart: ## Restart all services
	docker-compose restart

logs: ## Show logs for all services
	docker-compose logs -f

logs-app: ## Show logs for app service only
	docker-compose logs -f app

console: ## Open Rails console
	docker-compose run --rm app bundle exec rails c

c: console ## Shortcut for console

migrate: ## Run database migrations
	docker-compose run --rm app bundle exec rails db:migrate

seed: ## Seed the database
	docker-compose run --rm app bundle exec rails db:seed

test: ## Run all tests
	@echo "🏗️  Setting up test database..."
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rails db:test:prepare
	@echo "🧪 Running tests..."
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec

test-setup: ## Setup test database
	@echo "🏗️  Setting up test database..."
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rails db:test:prepare

test-auth: test-setup ## Run authentication tests only
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/requests/auth_spec.rb

test-users: test-setup ## Run user management tests only
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/requests/users_spec.rb

test-verification: test-setup ## Run email verification tests only
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/requests/verification_spec.rb

test-requests: test-setup ## Run all request specs
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/requests/

test-models: test-setup ## Run model tests only
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/models/

test-fast: test-setup ## Run tests with fast fail (stop on first failure)
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec --fail-fast

test-coverage: test-setup ## Run tests with coverage report
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec --format documentation

test-ci: test-setup ## Run tests for CI (with junit output)
	docker-compose run --rm -e RAILS_ENV=test app bundle exec rspec --format RspecJunitFormatter --out tmp/rspec.xml

db-create: ## Create database
	docker-compose run --rm app bundle exec rails db:create

db-drop: ## Drop database
	docker-compose run --rm app bundle exec rails db:drop

db-reset: ## Reset database (drop, create, migrate, seed)
	docker-compose run --rm app bundle exec rails db:drop
	docker-compose run --rm app bundle exec rails db:create
	docker-compose run --rm app bundle exec rails db:migrate
	docker-compose run --rm app bundle exec rails db:seed

shell: ## Open bash shell in app container
	docker-compose run --rm app bash

clean: ## Remove containers, volumes, and images
	docker-compose down -v
	docker system prune -f

routes: ## Show Rails routes
	docker-compose run --rm app bundle exec rails routes

bundle: ## Install gems
	docker-compose run --rm app bundle install

generate: ## Run Rails generator (use with ARGS="controller User")
	docker-compose run --rm app bundle exec rails generate $(ARGS)

g: generate ## Shortcut for generate

# Code Quality Tools
lint: ## Run RuboCop linter
	docker-compose run --rm app bundle exec rubocop

lint-fix: ## Auto-fix RuboCop violations
	docker-compose run --rm app bundle exec rubocop -A

security-check: ## Run Brakeman security scanner
	docker-compose run --rm app bundle exec brakeman -q

docs: ## Generate YARD documentation
	docker-compose run --rm app bundle exec yard doc

quality-check: lint security-check test ## Run all quality checks (lint, security, tests)
	@echo "✅ All quality checks passed!"

pre-commit-check: lint test ## Run pre-commit checks (lint and tests)
	@echo "✅ Pre-commit checks passed!"

# Git Hooks (Docker-based)
hooks-install: ## Install git hooks
	@echo "Installing pre-commit hook..."
	@rm -f .git/hooks/pre-commit
	@cp scripts/pre-commit.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed successfully!"
	@echo "The hook will run:"
	@echo "  - Debugging statement checks"
	@echo "  - RuboCop (linting & style)"
	@echo "  - Security checks (if Brakeman installed)"
	@echo "  - Schema consistency"
	@echo "  - Tests for changed files"
	@echo "  - File size validation"
	@echo "  - Merge conflict detection"
	@echo "  - YAML validation"

hooks-test: ## Test pre-commit hook manually
	@./scripts/pre-commit.sh

# Documentation Tools
docs-serve: ## Serve documentation locally
	docker-compose run --rm -p 8808:8808 app bundle exec yard server --reload --bind 0.0.0.0 --port 8808

docs-stats: ## Show documentation coverage statistics
	docker-compose run --rm app bundle exec yard stats --list-undoc

# RuboCop Utilities
rubocop-todo: ## Generate RuboCop TODO file for existing violations
	docker-compose run --rm app bundle exec rubocop --auto-gen-config

# Brakeman Utilities
security-report: ## Generate detailed HTML security report
	docker-compose run --rm app bundle exec brakeman -o brakeman-report.html

security-interactive: ## Run Brakeman in interactive mode
	docker-compose run --rm app bundle exec brakeman -I

# Environment Management
env-setup: ## Setup environment files from examples
	@echo "Setting up environment files..."
	@test -f config/env/.env.development || cp config/env/.env.example config/env/.env.development
	@test -f config/env/.env.staging || cp config/env/.env.example config/env/.env.staging
	@test -f config/env/.env.production || cp config/env/.env.example config/env/.env.production
	@echo "✅ Environment files created. Please update them with actual values."

env-check: ## Check if environment files exist
	@echo "Checking environment files..."
	@test -f config/env/.env.development && echo "✅ config/env/.env.development exists" || echo "❌ config/env/.env.development missing"
	@test -f config/env/.env.staging && echo "✅ config/env/.env.staging exists" || echo "❌ config/env/.env.staging missing"
	@test -f config/env/.env.production && echo "✅ config/env/.env.production exists" || echo "❌ config/env/.env.production missing"

# Development Environment
dev: dev-up ## Start development environment (alias)

dev-up: ## Start development environment
	./bin/docker-env development up

dev-down: ## Stop development environment
	./bin/docker-env development down

dev-logs: ## Show development logs
	./bin/docker-env development logs -f

dev-shell: ## Open shell in development
	./bin/docker-env development run --rm app bash

dev-console: ## Open Rails console in development
	./bin/docker-env development run --rm app rails c

# Staging Environment
staging: staging-up ## Start staging environment (alias)

staging-up: ## Start staging environment
	./bin/docker-env staging up

staging-down: ## Stop staging environment
	./bin/docker-env staging down

staging-logs: ## Show staging logs
	./bin/docker-env staging logs -f

staging-shell: ## Open shell in staging
	./bin/docker-env staging run --rm app bash

staging-console: ## Open Rails console in staging
	./bin/docker-env staging run --rm app rails c

staging-migrate: ## Run migrations in staging
	./bin/docker-env staging run --rm app rails db:migrate

# Production Environment
prod: prod-up ## Start production environment (alias)

prod-up: ## Start production environment (with confirmation)
	./bin/docker-env production up

prod-down: ## Stop production environment
	./bin/docker-env production down

prod-logs: ## Show production logs
	./bin/docker-env production logs -f

prod-shell: ## Open shell in production (use with caution!)
	@echo "⚠️  WARNING: You're about to open a shell in production!"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./bin/docker-env production run --rm app bash; \
	fi

prod-console: ## Open Rails console in production (use with caution!)
	@echo "⚠️  WARNING: You're about to open Rails console in production!"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./bin/docker-env production run --rm app rails c; \
	fi

prod-migrate: ## Run migrations in production (use with caution!)
	@echo "⚠️  WARNING: You're about to run migrations in production!"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./bin/docker-env production run --rm app rails db:migrate; \
	fi