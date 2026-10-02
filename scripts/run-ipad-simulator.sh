#!/bin/sh
# Builds the iPad app for the simulator, installs it and starts it.
#
# IPAD_SIMULATOR  name of the simulator to use (default: the first available iPad)
set -eu

cd "$(dirname "$0")/.."

DEVICE="${IPAD_SIMULATOR:-$(xcrun simctl list devices available | sed -n 's/^ *\(iPad[^(]*\) (.*/\1/p' | head -n 1 | sed 's/ *$//')}"
[ -n "$DEVICE" ] || { echo "Starting the simulator failed: no iPad simulator is installed." >&2; exit 1; }

xcodebuild -project ios/Scrollkeeper.xcodeproj -scheme Scrollkeeper-iPad \
    -destination "platform=iOS Simulator,name=$DEVICE" -derivedDataPath ios/build \
    CODE_SIGNING_ALLOWED=NO build | tail -n 3

APP="ios/build/Build/Products/Debug-iphonesimulator/Scrollkeeper.app"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" io.github.scooper4711.Scrollkeeper
