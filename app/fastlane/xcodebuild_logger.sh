#!/bin/bash
# This helper script:
# 1. Writes raw xcodebuild output to a log file
# 2. Forwards the output to xcbeautify for compacted stdout display

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log file path relative to the fastlane directory
LOG_FILE="$SCRIPT_DIR/../build/logs/xcodebuild.log"

# Ensure the log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Use tee to write to log file and pipe to xcbeautify
# The --quiet flag keeps xcbeautify output compact
tee "$LOG_FILE" | xcbeautify --quiet
