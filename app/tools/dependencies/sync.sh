#! /bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
CURRENT_DIR="$(pwd)"

cd "${ROOT_DIR}/app/tools/dependencies"

# Parse arguments
ALL_FLAG=""
for arg in "$@"; do
	case $arg in
	--all)
		ALL_FLAG="--all"
		shift
		;;
	esac
done

# Build the binary (with caching)
RELEASE=true source ./build-binary.sh

# Run the program
"${BINARY}" sync --path "${ROOT_DIR}/app/modules/Package.swift" ${ALL_FLAG}

# lint
cd "${ROOT_DIR}/app"
mkdir -p .build/caches/swiftformat
swiftformat --config rules.swiftformat ./**/Module.swift --cache .build/caches/swiftformat --quiet
swiftformat --config rules.swiftformat ./**/Package.swift --cache .build/caches/swiftformat --quiet

cd "${CURRENT_DIR}"
