#! /bin/bash

set -euo pipefail

# This script builds the sync-package-dependencies binary with caching.
# The cache will be invalidated if source files change.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CACHE_DIR="$HOME/.cmd/dev/tmp/bin"

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
