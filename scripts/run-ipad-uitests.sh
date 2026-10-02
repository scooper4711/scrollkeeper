#!/bin/sh
# Runs the iPad UI tests in a simulator. They drive the app in demo mode, so they need neither
# an account nor the network.
#
# IPAD_SIMULATOR  name of the simulator to use (default: an iPad on the newest iOS installed)
set -eu

cd "$(dirname "$0")/.."

DEVICE="$(scripts/ipad-simulator-id.sh)"
[ -n "$DEVICE" ] || { echo "Running the UI tests failed: no iPad simulator is installed." >&2; exit 1; }
echo "Running the UI tests on simulator $DEVICE..."

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
STATUS=0
xcodebuild test -project ios/Scrollkeeper.xcodeproj -scheme Scrollkeeper-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build > "$LOG" 2>&1 || STATUS=$?
grep -E " error: |Test Case .*(passed|failed)|\*\* TEST" "$LOG" || tail -n 20 "$LOG"
exit "$STATUS"
