#!/bin/bash

VERSION="1.0.0"

if [[ -n "$BUGSNAG_CLI_VERSION" ]]; then
  VERSION="$BUGSNAG_CLI_VERSION"
fi

if [[ "$1" == "--version" ]]; then
  echo "Version: $VERSION"
else
  echo "Usage: $0 [VERSION=x.y.z] --version"
fi
