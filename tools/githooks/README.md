# Git Hooks

This directory contains git hooks for the CMD repository.

## Automatic Setup

The hooks are automatically configured when you run `yarn install` in the `local-server` directory. The postinstall script configures git to use this directory for hooks via `git config core.hooksPath tools/githooks`.

This approach ensures hooks work correctly with:
- Git worktrees
- Fresh repository checkouts
- Multiple working directories

## Manual Setup

If you need to set up the hooks manually, run:

```bash
./tools/githooks/setup.sh
```

Or configure git directly:

```bash
git config core.hooksPath tools/githooks
```

## Available Hooks

### pre-commit

Runs before each commit to ensure code quality:
- `cmd lint` - Runs linting checks (Swift, TypeScript, shell, Ruby, YAML)
- `cmd sync:dependencies` - Syncs Swift package dependencies

How it works:
1. Unstaged changes are temporarily stashed (using `--keep-index` to preserve what you staged)
2. Lint and sync run on the full working tree
3. Any changes from lint/sync are automatically staged
4. Your original unstaged changes are restored to remain unstaged
5. The commit proceeds with your originally staged changes plus the lint/sync fixes

This preserves your staging intent - files you left unstaged remain unstaged.
