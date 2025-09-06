#!/bin/bash
set -euo pipefail

# Ensures that the js bundle that is copied in the app matches the local one.
# If you have `yarn watch` running from `./local-server`, the copied bundle should remain in sync.
# Otherwise it can get out of sync.
# This script is intended to be run as a build phase in Xcode.

# Parse arguments
PRE_BUILD_SCRIPT=false
for arg in "$@"; do
	case $arg in
	--pre-build)
		PRE_BUILD_SCRIPT=true
		shift
		;;
	esac
done

# When run as a build phase in Xcode, the environment is not set up correctly.
# Add Homebrew to the path to support yarn.
export PATH="$PATH:/opt/homebrew/bin:$HOME/.nvm/versions/node/v22.13.1/bin"

current_dir=$(pwd)
file_directory="$(realpath "$(dirname "$0")")"
cd "$file_directory"
repo_root=$(git rev-parse --show-toplevel)

PROXY_HASH_FILE="$repo_root/local-server/build.sha256"
APP_HASH_FILE="$repo_root/app/modules/services/LocalServerService/Sources/Resources/build.sha256"

copy_one_file() {
	local file_path="$1"
	local destination_dir="$2"
	mkdir -p "$destination_dir"
	destination_path="$destination_dir/$(basename "$file_path")"
	echo "cp \"$file_path\" \"$destination_path\""
	cp "$file_path" "$destination_path"
}

build_and_copy() {
	if [ ! -d "$repo_root/local-server/node_modules" ]; then
		echo "node_modules not found. Running yarn install..."
		(cd "$repo_root/local-server" && yarn install) || exit 1
	fi

	(cd "$repo_root/local-server" && yarn build && yarn copy-to-app) || exit 1
	if [ "${CONFIGURATION}" = "Release" ]; then
		echo "Building in Release mode"
		(cd "$repo_root/local-server" && yarn build:prod && yarn copy-to-app) || exit 1
	else
		echo "Building in Debug mode"
		(cd "$repo_root/local-server" && yarn build && yarn copy-to-app) || exit 1
	fi

	if [ "$PRE_BUILD_SCRIPT" = true ]; then
		echo "The local server has been updated."
		exit 0
	else
		# When run from Xcode as a build phase, this is executed after the files are copied from the package's bundle.
		# So we need to exit with a non-zero exit code to indicate that the build needs to be restarted with the correct files.
		echo "The local server has been updated. Please restart the build." >&2
		exit 1
	fi
}

# Sync the schema
(cd "$repo_root/local-server" && yarn export-schema-swift) || exit 1

# Check if the app hash file exists
if [ ! -f "$APP_HASH_FILE" ]; then
	echo "App hash file $APP_HASH_FILE doesn't exist. Running build..."
	build_and_copy
fi

# Compare the hash files
if ! cmp -s "$PROXY_HASH_FILE" "$APP_HASH_FILE"; then
	echo "Build hashes differ. Running build..."
	build_and_copy
else
	echo "Build is up to date."
fi

cd "$current_dir"
