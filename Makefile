.PHONY: help setup build up down restart logs console migrate seed test clean db-create db-drop db-reset shell lint lint-fix security-check docs quality-check hooks-install hooks-test docs-serve docs-stats rubocop-todo security-report security-interactive

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Initial setup - build, create db, migrate, and start
	docker-compose build
	docker-compose run --rm app rails db:create
	docker-compose run --rm app rails db:migrate
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
	docker-compose run --rm app rails c

c: console ## Shortcut for console

migrate: ## Run database migrations
	docker-compose run --rm app rails db:migrate

seed: ## Seed the database
	docker-compose run --rm app rails db:seed

test: ## Run tests
	docker-compose run --rm app bundle exec rspec

db-create: ## Create database
	docker-compose run --rm app rails db:create

db-drop: ## Drop database
	docker-compose run --rm app rails db:drop

db-reset: ## Reset database (drop, create, migrate, seed)
	docker-compose run --rm app rails db:drop
	docker-compose run --rm app rails db:create
	docker-compose run --rm app rails db:migrate
	docker-compose run --rm app rails db:seed

shell: ## Open bash shell in app container
	docker-compose run --rm app bash

clean: ## Remove containers, volumes, and images
	docker-compose down -v
	docker system prune -f

routes: ## Show Rails routes
	docker-compose run --rm app rails routes

bundle: ## Install gems
	docker-compose run --rm app bundle install

generate: ## Run Rails generator (use with ARGS="controller User")
	docker-compose run --rm app rails generate $(ARGS)

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

# Git Hooks (Docker-based)
hooks-install: ## Install git hooks
	@echo "Git hooks already installed via scripts/pre-commit.sh"
	@echo "Hooks run RuboCop in Docker automatically on commit"

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