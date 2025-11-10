#!/bin/sh

# Setup git hooks for this repository
# This script configures git to use the tools/githooks directory

HOOKS_DIR="tools/githooks"

echo "Setting up git hooks..."

# Navigate to repo root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$repo_root" ]; then
    echo "❌ Not a git repository"
    exit 1
fi

cd "$repo_root"

# Configure git to use the tools/githooks directory
git config core.hooksPath "$HOOKS_DIR"

if [ $? -eq 0 ]; then
    echo "✓ Git hooks configured successfully"
    echo "  Hooks directory: $HOOKS_DIR"
else
    echo "❌ Failed to configure git hooks"
    exit 1
fi
