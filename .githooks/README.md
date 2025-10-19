# Git Hooks

This directory contains git hooks for the heyho-sync-be repository to maintain code quality.

## Installation

Run the install script to set up git hooks:

```bash
.githooks/install.sh
```

## Available Hooks

### pre-commit

Runs RuboCop on all staged Ruby files before allowing a commit.

**What it does:**
- Checks `.rb` and `.rake` files that are staged for commit
- Runs RuboCop with the project's configuration
- Blocks commit if any violations are found
- Shows helpful error messages with fix instructions

**To bypass (not recommended):**
```bash
git commit --no-verify
```

**To auto-fix issues:**
```bash
make lint-fix
# Or
docker-compose run --rm --no-deps heyho-sync-be bundle exec rubocop -A
```

## Why Git Hooks?

Git hooks help maintain code quality by:
- Catching style violations before they reach CI
- Ensuring consistent code style across the team
- Reducing PR review time
- Preventing broken builds

## Troubleshooting

**Hook not running?**
- Make sure you ran `.githooks/install.sh`
- Check that `.git/hooks/pre-commit` exists and is executable

**Hook failing?**
- Run `make lint` to see all violations
- Run `make lint-fix` to auto-fix most issues
- Fix remaining issues manually

**Need to commit despite violations?**
- Fix the violations first (recommended)
- Or use `git commit --no-verify` (not recommended)
