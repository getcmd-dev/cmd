#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Build the binary (with caching)
source ./build-binary.sh

# Find all test resource directories
TEST_RESOURCES_DIR="./Tests/resources"

if [ ! -d "${TEST_RESOURCES_DIR}" ]; then
	echo "Error: Test resources directory not found at ${TEST_RESOURCES_DIR}"
	exit 1
fi

# Get all directories in the test resources folder
TEST_REPOS=$(find "${TEST_RESOURCES_DIR}" -mindepth 1 -maxdepth 1 -type d)

if [ -z "${TEST_REPOS}" ]; then
	echo "No test repositories found in ${TEST_RESOURCES_DIR}"
	exit 0
fi

echo "Running sync for test repositories..."
echo ""

# Run the binary for each test repo
for repo_path in ${TEST_REPOS}; do
	repo_name=$(basename "${repo_path}")

	if [ ! -f "${repo_path}/Package.template.swift" ]; then
		echo "⚠️  Skipping ${repo_name}: No Package.template.swift found"
		continue
	fi

	echo "Processing ${repo_name}..."
	"${BINARY}" sync --path "${repo_path}/Package.swift" --all

	echo ""
done
