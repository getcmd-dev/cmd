#! /bin/bash

set -euo pipefail

# This script builds the sync-package-dependencies binary with caching.
# The cache will be invalidated if source files change.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

BASE_CACHE_DIR="$HOME/.cmd/dev/tmp/bin/sync-package-dependencies"
CACHE_DIR="$BASE_CACHE_DIR"

# Calculate hash of all git-tracked source files
CURRENT_HASH=$(git ls-files . 2>/dev/null | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
CACHE_DIR="$CACHE_DIR/$CURRENT_HASH"

IS_RELEASE=false
if [ -n "${RELEASE:-}" ]; then
	CACHE_DIR="$CACHE_DIR/release"
	IS_RELEASE=true
else
	CACHE_DIR="$CACHE_DIR/debug"
fi
CACHE_BINARY="${CACHE_DIR}/SwiftModuleCommand"
BINARY="${CACHE_DIR}/SwiftModuleCommand"

# Check if we need to rebuild
REBUILD=false
if [ ! -f "${BINARY}" ]; then
	echo "No cached binary at $BINARY. Rebuilding..."
	REBUILD=true

	# Keep last 5 most recent files/directories.
	# This limits cache size, while allowing for cache hits for recent versions - which is useful when changing branches around a version change.
	if [ -d "${BASE_CACHE_DIR}" ]; then
		echo "Keeping last 10 most recent cache entries..."
		cd "${BASE_CACHE_DIR}"
		# List all items sorted by modification time (newest first), skip first 10, remove rest
		ls -dt 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null || true
		cd - >/dev/null
	fi
fi

mkdir -p "${CACHE_DIR}"

if [ "${REBUILD}" = true ]; then
	if [ "${IS_RELEASE}" = true ]; then
		swift build -c release
		cp ".build/release/SwiftModuleCommand" "${CACHE_DIR}"
	else
		swift build
		cp ".build/debug/SwiftModuleCommand" "${CACHE_DIR}"
	fi
fi

# Export the binary path for use by calling scripts
export BINARY="${BINARY}"
