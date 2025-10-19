#!/bin/bash
# Install git hooks for this repository

set -e

echo "Installing git hooks..."

# Get the directory where this script is located
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_HOOKS_DIR="$(git rev-parse --show-toplevel)/.git/hooks"

# Install pre-commit hook
if [ -f "$HOOKS_DIR/pre-commit" ]; then
  cp "$HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
  chmod +x "$GIT_HOOKS_DIR/pre-commit"
  echo "✓ Installed pre-commit hook"
else
  echo "⚠️  pre-commit hook not found in $HOOKS_DIR"
fi

echo ""
echo "✅ Git hooks installed successfully!"
echo ""
echo "The pre-commit hook will now run RuboCop on staged files before each commit."
echo "To bypass the hook (not recommended), use: git commit --no-verify"
