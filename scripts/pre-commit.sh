#!/bin/bash
# Pre-commit hook following Rails and CLAUDE.md best practices
# This script ensures code quality before commits

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Running pre-commit checks...${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

# Get all staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)
STAGED_RUBY_FILES=$(echo "$STAGED_FILES" | grep '\.rb$' | grep -v '^config/' | grep -v '^db/' || true)
STAGED_SPEC_FILES=$(echo "$STAGED_FILES" | grep 'spec/.*\.rb$' || true)
STAGED_APP_FILES=$(echo "$STAGED_FILES" | grep -E 'app/.*\.rb$|lib/.*\.rb$|config/.*\.rb$' || true)

# Track if any checks fail
CHECKS_FAILED=0

# 1. Check for debugging statements
if [ -n "$STAGED_RUBY_FILES" ]; then
    echo -e "${YELLOW}🔍 Checking for debugging statements...${NC}"

    # Check for common debugging statements (exclude comments and strings)
    DEBUG_PATTERNS="^\s*(binding\.pry|byebug|debugger|puts\s+['\"]DEBUG|pp\s+)"
    if echo "$STAGED_RUBY_FILES" | xargs grep -E "$DEBUG_PATTERNS" 2>/dev/null | grep -v "^\s*#"; then
        echo -e "${RED}❌ Found debugging statements. Please remove them before committing.${NC}"
        CHECKS_FAILED=1
    else
        echo -e "${GREEN}✅ No debugging statements found${NC}"
    fi
fi

# 2. Run RuboCop for style and linting
if [ -n "$STAGED_RUBY_FILES" ]; then
    echo -e "${YELLOW}🎨 Running RuboCop for code style...${NC}"

    # Create a temporary file with staged file list
    echo "$STAGED_RUBY_FILES" > /tmp/staged_files.txt

    # Run RuboCop on staged files
    docker-compose run --rm -T app bundle exec rubocop $(echo $STAGED_RUBY_FILES) --format simple > /tmp/rubocop_output.txt 2>&1
    RUBOCOP_EXIT=$?

    if [ $RUBOCOP_EXIT -eq 0 ]; then
        echo -e "${GREEN}✅ RuboCop checks passed${NC}"
    else
        echo -e "${RED}❌ RuboCop found issues${NC}"
        cat /tmp/rubocop_output.txt | head -20
        echo -e "${YELLOW}💡 Run 'make lint-fix' to auto-fix some issues${NC}"
        CHECKS_FAILED=1
    fi
fi

# 3. Check for security issues with Brakeman (if Gemfile includes it)
if [ -n "$STAGED_APP_FILES" ]; then
    if grep -q "gem.*brakeman" Gemfile 2>/dev/null; then
        echo -e "${YELLOW}🔒 Running security checks with Brakeman...${NC}"

        # Run Brakeman and check exit code (3 = no issues, 0 = issues found)
        docker-compose run --rm -T app bundle exec brakeman -q --no-pager > /dev/null 2>&1
        BRAKEMAN_EXIT=$?

        if [ $BRAKEMAN_EXIT -eq 3 ] || [ $BRAKEMAN_EXIT -eq 0 ]; then
            echo -e "${GREEN}✅ Security checks passed${NC}"
        else
            echo -e "${RED}❌ Brakeman found security issues${NC}"
            echo -e "${YELLOW}💡 Run 'make security-check' for details${NC}"
            CHECKS_FAILED=1
        fi
    fi
fi

# 4. Check for schema/migration consistency
if echo "$STAGED_FILES" | grep -q 'db/migrate/.*\.rb$'; then
    echo -e "${YELLOW}🗃️  Checking database schema consistency...${NC}"

    # Check if schema.rb is also staged when migrations are staged
    if ! echo "$STAGED_FILES" | grep -q 'db/schema.rb'; then
        echo -e "${RED}❌ Migration files changed but db/schema.rb not staged${NC}"
        echo -e "${YELLOW}💡 Run 'make migrate' and stage db/schema.rb${NC}"
        CHECKS_FAILED=1
    else
        echo -e "${GREEN}✅ Database schema is consistent${NC}"
    fi
fi

# 5. Run tests for changed code
if [ -n "$STAGED_APP_FILES" ] || [ -n "$STAGED_SPEC_FILES" ]; then
    echo -e "${YELLOW}🧪 Running tests...${NC}"

    # Determine which tests to run based on changed files
    TEST_FILES=""

    # If spec files changed, run them
    if [ -n "$STAGED_SPEC_FILES" ]; then
        TEST_FILES="$STAGED_SPEC_FILES"
    else
        # Run all tests if only app files changed (safer)
        TEST_FILES="spec/"
    fi

    # Setup test database
    echo -e "${BLUE}🏗️  Preparing test database...${NC}"
    docker-compose run --rm -T -e RAILS_ENV=test app bundle exec rails db:test:prepare > /dev/null 2>&1

    # Run tests
    if docker-compose run --rm -T -e RAILS_ENV=test app bundle exec rspec $TEST_FILES --format progress --fail-fast; then
        echo -e "${GREEN}✅ All tests passed${NC}"
    else
        echo -e "${RED}❌ Tests failed${NC}"
        echo -e "${YELLOW}💡 Fix failing tests or run 'make test' to debug${NC}"
        CHECKS_FAILED=1
    fi
fi

# 6. Check for large files
echo -e "${YELLOW}📦 Checking file sizes...${NC}"
LARGE_FILES=$(echo "$STAGED_FILES" | while read -r file; do
    if [ -f "$file" ]; then
        SIZE=$(wc -c < "$file")
        if [ $SIZE -gt 1000000 ]; then  # 1MB
            echo "$file"
        fi
    fi
done)

if [ -n "$LARGE_FILES" ]; then
    echo -e "${RED}❌ Large files detected (>1MB):${NC}"
    echo "$LARGE_FILES"
    echo -e "${YELLOW}💡 Consider using Git LFS for large files${NC}"
    CHECKS_FAILED=1
else
    echo -e "${GREEN}✅ No large files detected${NC}"
fi

# 7. Check for merge conflict markers
if [ -n "$STAGED_FILES" ]; then
    echo -e "${YELLOW}🔀 Checking for merge conflict markers...${NC}"

    CONFLICT_MARKERS="<<<<<<<|>>>>>>>|======="
    if echo "$STAGED_FILES" | grep -v "pre-commit.sh" | xargs grep -E "$CONFLICT_MARKERS" 2>/dev/null; then
        echo -e "${RED}❌ Found merge conflict markers${NC}"
        CHECKS_FAILED=1
    else
        echo -e "${GREEN}✅ No merge conflict markers found${NC}"
    fi
fi

# 8. Validate YAML files
STAGED_YAML=$(echo "$STAGED_FILES" | grep -E '\.(yml|yaml)$' || true)
if [ -n "$STAGED_YAML" ]; then
    echo -e "${YELLOW}📝 Validating YAML files...${NC}"

    for file in $STAGED_YAML; do
        if ! ruby -ryaml -e "YAML.load_file('$file')" 2>/dev/null; then
            echo -e "${RED}❌ Invalid YAML in $file${NC}"
            CHECKS_FAILED=1
        fi
    done

    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All YAML files are valid${NC}"
    fi
fi

# Final result
echo ""
if [ $CHECKS_FAILED -ne 0 ]; then
    echo -e "${RED}❌ Pre-commit checks failed. Please fix the issues above.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All pre-commit checks passed! Ready to commit.${NC}"
    exit 0
fi