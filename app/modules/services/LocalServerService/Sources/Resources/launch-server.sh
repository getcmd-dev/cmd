#! /bin/bash

# This script is used to launch the server.
# It is used to launch the server in a separate process,
# so that the server can be killed without killing the main process.

DESIRED_NODE_VERSION="22"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR"

setup_node_environment() {
	# Check if there's a local Node executable
	if [ -f "./node" ] && [ -x "./node" ]; then
		local LOCAL_NODE_VERSION=$(./node --version)
		if [[ ${LOCAL_NODE_VERSION:1:2} == $DESIRED_NODE_VERSION ]]; then
			return 0
		fi
	fi

	local ORIGINAL_SYSTEM_NODE_VERSION=""
	# Check if nvm is already installed globally
	if [ -n "$NVM_DIR" ]; then
		# nvm already installed
		:
	else
		# Installing nvm
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
		NVM_DIR="$HOME/.nvm"
	fi

	# Source NVM, this is because nvm is a shell function, not an executable
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
	ORIGINAL_SYSTEM_NODE_VERSION=$(nvm current)

	# Install the correct Node.js version
	if ! nvm ls $DESIRED_NODE_VERSION >/dev/null 2>&1; then
		# Installing the correct node version
		nvm install $DESIRED_NODE_VERSION
	fi

	node_path=$(nvm which $DESIRED_NODE_VERSION)

	cp $node_path ./node

	# Restore original Node version if it existed
	if [ ! -z "$ORIGINAL_SYSTEM_NODE_VERSION" ]; then
		nvm use "$ORIGINAL_SYSTEM_NODE_VERSION"
	fi
}

setup_dependencies() {
	# download ripgrep
	if [ ! -f "./rg-14.1.1" ]; then
		curl -L https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-aarch64-apple-darwin.tar.gz -o ripgrep-14.1.1.tar.gz
		# unzip to ./rg-14.1.1
		tar -xzf ripgrep-14.1.1.tar.gz
		mv ripgrep-14.1.1-aarch64-apple-darwin/rg ./rg-14.1.1
		rm -rf ripgrep-14.1.1-aarch64-apple-darwin
		rm ripgrep-14.1.1.tar.gz
	fi
}

setup_node_environment >"./launch-server.log" 2>&1
setup_dependencies >"./launch-server.log" 2>&1

./node --enable-source-maps ./main.bundle.cjs "$@" 2> >(tee "./launch-server.stderr.log") 1> >(tee "./launch-server.stdout.log")
