#!/bin/sh
# Prints the app's version, so the iPad and Mac builds agree.
#
#   scripts/version.sh marketing   the version in the VERSION file (1.2.0): the release now being worked toward
#   scripts/version.sh build       the build number: the commit count, which grows with every commit on main
#   scripts/version.sh xcconfig    both, as Xcode build settings (written to ios/Version.xcconfig)
#
# A v* tag no longer names the version: it marks the build Apple accepted for that version.
set -eu

cd "$(dirname "$0")/.."

marketing() {
    version=""
    if [ -f VERSION ]; then
        version="$(tr -d '[:space:]' < VERSION)"
    fi
    if ! echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "Reading the version failed: VERSION must hold a version such as 1.2.0." >&2
        exit 1
    fi
    echo "$version"
}

build() {
    # A shallow clone counts only the commits it fetched, which would make a build number go backwards.
    if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
        echo "Reading the build number failed: the clone is shallow; fetch the full history." >&2
        exit 1
    fi
    git rev-list --count HEAD
}

xcconfig() {
    # Assigned first, so a failure stops the script instead of writing an empty setting.
    version="$(marketing)"
    number="$(build)"
    echo "// Written by scripts/version.sh; not committed."
    echo "MARKETING_VERSION = $version"
    echo "CURRENT_PROJECT_VERSION = $number"
}

case "${1:-}" in
    marketing) marketing ;;
    build) build ;;
    xcconfig) xcconfig ;;
    *) echo "Usage: scripts/version.sh marketing|build|xcconfig" >&2; exit 2 ;;
esac
