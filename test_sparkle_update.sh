#!/bin/bash

set -e

echo "=========================================="
echo "Sparkle Update Test Script"
echo "=========================================="

# Configuration
APP_DIR="/Users/guigui/dev/conductor/cmd/.conductor/santiago/app"
BUILD_DIR="$APP_DIR/../.build"
APP_PATH="$BUILD_DIR/cmd.app"
LOG_FILE="/tmp/sparkle_test_$(date +%Y%m%d_%H%M%S).log"
WAIT_TIME=60

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Looking for built app...${NC}"

# First check if app already exists from recent build
BUILT_APP=$(ls -d /Users/guigui/Library/Developer/Xcode/DerivedData/command-*/Build/Products/Release/cmd.app 2>/dev/null | head -1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    echo -e "${YELLOW}No existing build found. Skipping - please build manually first${NC}"
    exit 1
fi

if [ ! -d "$BUILT_APP" ]; then
    echo -e "${RED}ERROR: Could not find built app${NC}"
    exit 1
fi

echo -e "${GREEN}Built app at: $BUILT_APP${NC}"

echo -e "${YELLOW}Step 2: Launching app...${NC}"
open "$BUILT_APP"

# Get the app process name (without .app extension)
APP_NAME=$(basename "$BUILT_APP" .app)
echo "App process name: $APP_NAME"

# Wait for app to start
sleep 3

# Check if app is running
if ! pgrep -x "$APP_NAME" > /dev/null; then
    echo -e "${RED}ERROR: App did not start successfully${NC}"
    exit 1
fi

APP_PID=$(pgrep -x "$APP_NAME")
echo -e "${GREEN}App launched with PID: $APP_PID${NC}"

echo -e "${YELLOW}Step 3: Starting log collection...${NC}"
# Start log streaming in background
log stream --predicate 'process == "'"$APP_NAME"'" OR process == "Autoupdate"' --level debug > "$LOG_FILE" 2>&1 &
LOG_PID=$!

echo -e "${YELLOW}Waiting ${WAIT_TIME} seconds for update process...${NC}"
echo "(Trigger the update manually in the app now)"

# Wait for specified time
for i in $(seq 1 $WAIT_TIME); do
    if ! kill -0 $APP_PID 2>/dev/null; then
        echo -e "${RED}App crashed or quit at $i seconds${NC}"
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

echo -e "${YELLOW}Step 4: Stopping app and log collection...${NC}"
# Kill the app
if kill -0 $APP_PID 2>/dev/null; then
    kill $APP_PID
    echo "App stopped"
fi

# Stop log collection
sleep 2
kill $LOG_PID 2>/dev/null || true

echo -e "${YELLOW}Step 5: Analyzing logs...${NC}"
echo "Full logs saved to: $LOG_FILE"
echo ""

echo -e "${GREEN}=== SPARKLE DEBUG LOGS ===${NC}"
grep "SPARKLE DEBUG" "$LOG_FILE" || echo "No SPARKLE DEBUG logs found"

echo ""
echo -e "${GREEN}=== ABORT/ERROR MESSAGES ===${NC}"
grep -i "abort\|error\|fail\|invalid" "$LOG_FILE" | grep -i sparkle || echo "No abort/error messages found"

echo ""
echo -e "${GREEN}=== CONNECTION STATUS ===${NC}"
grep "CONNECTION\|connection" "$LOG_FILE" | grep -i sparkle || echo "No connection logs found"

echo ""
echo -e "${YELLOW}=========================================="
echo "Test complete!"
echo "Full log file: $LOG_FILE"
echo "==========================================${NC}"
