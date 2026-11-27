#!/bin/sh
# Runs the iPad UI tests in a simulator. They drive the app in demo mode, so they need neither
# an account nor the network.
#
# Each run drives a simulator of its own: a copy of the one chosen, erased first and deleted afterward. A simulator
# that is used again keeps what earlier runs saved (the details left open, which cover the sign-in screen's demo
# button), and the CI Macs run several jobs at once, which would otherwise share one simulator. On the CI Macs
# (toolkit-ci-runner's simulator.sh installed), a run instead borrows its CI slot's simulator, which stays booted
# between jobs and is reset rather than erased: booting one costs minutes of CPU.
#
# IPAD_SIMULATOR  name of the simulator to copy (default: an iPad on the newest iOS installed)
set -eu

cd "$(dirname "$0")/.."

SOURCE="$(scripts/ipad-simulator-id.sh)"
[ -n "$SOURCE" ] || { echo "Running the UI tests failed: no iPad simulator is installed." >&2; exit 1; }
CI_SIMULATOR=/usr/local/libexec/ci-slots/simulator.sh
LOG="$(mktemp)"
DEVICE=""
[ -x "$CI_SIMULATOR" ] && DEVICE="$("$CI_SIMULATOR" checkout "$SOURCE")"
if [ -n "$DEVICE" ]; then
    give_back() {
        "$CI_SIMULATOR" checkin "$DEVICE" >/dev/null 2>&1 || true
        rm -f "$LOG"
    }
    trap give_back EXIT
    echo "Running the UI tests on simulator $DEVICE, this CI slot's (kept booted, reset)..."
else
    DEVICE="$(xcrun simctl clone "$SOURCE" "UI tests $$")" \
        || { echo "Running the UI tests failed: simulator $SOURCE couldn't be copied (is it booted?)." >&2; exit 1; }
    remove_copy() {
        xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
        xcrun simctl delete "$DEVICE" >/dev/null 2>&1 || true
        rm -f "$LOG"
    }
    trap remove_copy EXIT
    xcrun simctl erase "$DEVICE"
    echo "Running the UI tests on simulator $DEVICE, a fresh copy of $SOURCE..."
fi
trap 'exit 1' INT TERM

STATUS=0
xcodebuild test -project ios/Scrollkeeper.xcodeproj -scheme Scrollkeeper-iPad \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath ios/build > "$LOG" 2>&1 || STATUS=$?
grep -E " error: |Test Case .*(passed|failed)|\*\* TEST" "$LOG" || tail -n 20 "$LOG"
exit "$STATUS"
