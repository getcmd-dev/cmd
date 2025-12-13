#!/bin/bash

# ensure-language-server.sh
# Downloads and ensures GitHub Copilot language server is available

set -e

# Version of the language server to download
VERSION="$COPILOT_LANGUAGE_SERVER_VERSION"
BINARY_PATH="$COPILOT_LANGUAGE_SERVER_INSTALL_PATH"

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
	DOWNLOAD_URL="https://registry.npmjs.org/@github/copilot-language-server-darwin-arm64/-/copilot-language-server-darwin-arm64-${VERSION}.tgz"
elif [ "$ARCH" = "x86_64" ]; then
	DOWNLOAD_URL="https://registry.npmjs.org/@github/copilot-language-server-darwin-x64/-/copilot-language-server-darwin-x64-${VERSION}.tgz"
else
	echo "ERROR: Unsupported architecture: $ARCH" >&2
	exit 1
fi

# Check if binary already exists
if [ -f "$BINARY_PATH" ] && [ -x "$BINARY_PATH" ]; then
	# Binary exists and is executable
	exit 0
fi

# Binary doesn't exist, download it
echo "Downloading language server for $ARCH..." >&2

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

# Download
TGZ_FILE="$TEMP_DIR/copilot.tgz"
if ! curl -f -s -S -L -o "$TGZ_FILE" "$DOWNLOAD_URL" 2>&1; then
	echo "ERROR: Failed to download language server" >&2
	exit 1
fi

# Extract
if ! tar -xzf "$TGZ_FILE" -C "$TEMP_DIR" 2>&1; then
	echo "ERROR: Failed to extract language server" >&2
	exit 1
fi

# Move binary to Application Support
EXTRACTED_BINARY="$TEMP_DIR/package/copilot-language-server"
if [ ! -f "$EXTRACTED_BINARY" ]; then
	echo "ERROR: Binary not found in extracted package" >&2
	exit 1
fi

mv "$EXTRACTED_BINARY" "$BINARY_PATH"
chmod +x "$BINARY_PATH"

# Remove quarantine attribute to avoid Gatekeeper prompt
xattr -d com.apple.quarantine "$BINARY_PATH" 2>/dev/null || true

echo "Language server downloaded successfully" >&2

# Verify it works
if [ -x "$BINARY_PATH" ]; then
	exit 0
else
	echo "ERROR: Binary is not executable" >&2
	exit 1
fi
