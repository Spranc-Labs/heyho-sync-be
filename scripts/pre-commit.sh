#!/bin/bash
# Pre-commit hook that runs Docker-based checks

echo "Running pre-commit checks..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Get staged Ruby files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.rb$')

if [ -n "$STAGED_FILES" ]; then
    echo "🔍 Running RuboCop on staged Ruby files..."

    # Run RuboCop in Docker on staged files
    docker-compose run --rm app bundle exec rubocop $STAGED_FILES
    RUBOCOP_EXIT=$?

    if [ $RUBOCOP_EXIT -ne 0 ]; then
        echo "❌ RuboCop found issues. Fix them or run 'make lint-fix'"
        exit 1
    fi

    echo "✅ RuboCop checks passed!"
fi

echo "✅ All pre-commit checks passed!"
exit 0