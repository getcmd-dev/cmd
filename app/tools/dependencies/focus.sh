#! /bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
CURRENT_DIR="$(pwd)"

cd "${ROOT_DIR}/app/tools/dependencies"

# Cache the built binary, as for some reasons it gets rebuilt every time otherwise.
# The cache will need to be manually cleaned if the binary is updated.
if [ ! -f "./tmp/bin/sync-package-dependencies" ]; then
	swift build -c release
	mkdir -p tmp
	mkdir -p tmp/bin
	cp ".build/release/SyncPackageDependenciesCommand" "./tmp/bin/sync-package-dependencies"
fi

# If --list is provided, list the packages and exit
if [[ "$*" == *"--list"* ]]; then
	./tmp/bin/sync-package-dependencies focus --path "${ROOT_DIR}/app/modules/Package.swift" "$@"

	# lint Package.swift / Module.swift
	cd "${ROOT_DIR}/app"
	mkdir -p .build/caches/swiftformat
	swiftformat --config rules.swiftformat ./**/Module.swift --cache .build/caches/swiftformat --quiet
	swiftformat --config rules.swiftformat ./**/Package.swift --cache .build/caches/swiftformat --quiet

	exit 0
fi

package_path_for_module=$("./tmp/bin/sync-package-dependencies" focus --path "${ROOT_DIR}/app/modules/Package.swift" "$@")

# lint Package.swift / Module.swift
cd "${ROOT_DIR}/app"
mkdir -p .build/caches/swiftformat
swiftformat --config rules.swiftformat ./**/Module.swift --cache .build/caches/swiftformat --quiet
swiftformat --config rules.swiftformat ./**/Package.swift --cache .build/caches/swiftformat --quiet

# open the package in xcode
xcode_path=$(xcode-select -p)
xcode_path="${xcode_path%%.app*}.app"
echo "Opening package at: ${package_path_for_module}"
# Tell Xcode to not re-open windows that were open when it quit,
# to avoid having several windows using the same files which Xcode doesn't support.
open -a "$xcode_path" "$package_path_for_module" --args -ApplePersistenceIgnoreState YES
