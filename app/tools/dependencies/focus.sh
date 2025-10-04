#! /bin/bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
CURRENT_DIR="$(pwd)"

cd "${ROOT_DIR}/app/tools/dependencies"

# Parse input flags
should_open_in_xcode=false
parsed_args=()
for arg in "$@"; do
	if [ "$arg" = "--open" ]; then
		should_open_in_xcode=true
	else
		parsed_args+=("$arg")
	fi
done

# Cache the built binary, as for some reasons it gets rebuilt every time otherwise.
# The cache will need to be manually cleaned if the binary is updated.
if [ ! -f "./tmp/bin/sync-package-dependencies" ]; then
	swift build -c release
	mkdir -p tmp
	mkdir -p tmp/bin
	cp ".build/release/SyncPackageDependenciesCommand" "./tmp/bin/sync-package-dependencies"
fi

output=$("./tmp/bin/sync-package-dependencies" focus --path "${ROOT_DIR}/app/modules/Package.swift" "${parsed_args[@]}")

# lint Package.swift / Module.swift
cd "${ROOT_DIR}/app"
mkdir -p .build/caches/swiftformat
swiftformat --config rules.swiftformat ./**/Module.swift --cache .build/caches/swiftformat --quiet
swiftformat --config rules.swiftformat ./**/Package.swift --cache .build/caches/swiftformat --quiet

# If --list is provided, list the packages and exit
if [[ "$*" == *"--list"* ]]; then
	echo $output
	exit 0
fi

if [ "$should_open_in_xcode" = true ]; then
	package_path_for_module=$output
	# open the package in xcode
	xcode_path=$(xcode-select -p)
	xcode_path="${xcode_path%%.app*}.app"
	echo "Opening package at: ${package_path_for_module}"
	# Tell Xcode to not re-open windows that were open when it quit,
	# to avoid having several windows using the same files which Xcode doesn't support.
	open -a "$xcode_path" "$package_path_for_module" --args -ApplePersistenceIgnoreState YES
	echo "👉 Don't forget to use 'cmd open:app' the next time you re-open the app's xcodeproj, instead of opening it manually."
else
	echo $output
fi
