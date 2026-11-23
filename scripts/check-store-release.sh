#!/usr/bin/env bash
# Guards a Mac App Store build. Specified in docs/specs/app-store-pipeline.
#
# Usage: check-store-release.sh source     before building: the commit is on main, clean, and matches a version tag
#        check-store-release.sh package    after building: the package is universal, signed and has this build number
set -euo pipefail

APP=build/appstore/Scrollkeeper.app
PKG=build/appstore/Scrollkeeper.pkg
BUNDLE_ID=io.github.scooper4711.Scrollkeeper

fail() { echo "check-store-release: $*" >&2; exit 1; }

check_source() {
    git merge-base --is-ancestor HEAD origin/main || fail "$(git rev-parse --short HEAD) is not on origin/main"
    [[ -z "$(git status --porcelain)" ]] || fail "the working tree has changes"
    if [[ "${GITHUB_REF_TYPE:-}" == tag ]]; then
        [[ "${GITHUB_REF_NAME:-}" == "v$(scripts/version.sh marketing)" ]] \
            || fail "tag ${GITHUB_REF_NAME:-} doesn't match version $(scripts/version.sh marketing)"
    fi
}

check_package() {
    local build archs
    [[ -f "$PKG" ]] || fail "$PKG was not built"
    build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
    [[ "$build" == "$(scripts/version.sh build)" ]] || fail "the package has build $build"
    archs="$(lipo -archs "$APP/Contents/MacOS/Scrollkeeper")"
    [[ "$archs" == *arm64* && "$archs" == *x86_64* ]] || fail "the app isn't universal: $archs"
    codesign --verify --strict "$APP" || fail "the app's signature is invalid"
    codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "$BUNDLE_ID" \
        || fail "the app's entitlements don't name $BUNDLE_ID"
    pkgutil --check-signature "$PKG" | grep -q 'signed' || fail "the package isn't signed"
}

case "${1:-}" in
    source) check_source ;;
    package) check_package ;;
    *) fail "usage: check-store-release.sh source|package" ;;
esac
