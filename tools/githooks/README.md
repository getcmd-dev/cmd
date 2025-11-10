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

### pre-push

Runs before each push to ensure code quality:
- `cmd lint` - Runs linting checks (Swift, TypeScript, shell, Ruby, YAML)
- `cmd sync:dependencies` - Syncs Swift package dependencies

If these commands create changes:
1. All uncommitted changes are temporarily stashed
2. A fixup commit is automatically created with the lint/sync changes
3. Your stashed changes are restored
4. The push proceeds with the new fixup commit included
