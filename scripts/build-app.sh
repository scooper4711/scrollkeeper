#!/bin/sh
# Builds "build/Scrollkeeper.app" from the Swift package.
#
# VERSION    version written to the bundle (default 0.0.0)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
# TEAM_ID    the team that owns the App Group (default: read from the Developer ID certificate)
# SIGNING_IDENTITY  passed to scripts/sign-app.sh; "-" signs ad hoc, without the App Group
# CHANNEL    "appstore" builds the Mac App Store package (build/appstore/Scrollkeeper.pkg) from the same sources,
#            compiled with -DAPP_STORE so the updater and the Ko-fi link are left out; needs BUILD_NUMBER, TEAM_ID
#            and the variables of tabletop-kit's scripts/package-appstore.sh (TRIAL=1 checks it without them)
# BUILD_NUMBER  CFBundleVersion, which must increase with every upload (default: VERSION)
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
APP="build/Scrollkeeper.app"
EXECUTABLE="Scrollkeeper"

SWIFT_FLAGS=""
if [ "${CHANNEL:-}" = "appstore" ]; then
    SWIFT_FLAGS="-Xswiftc -DAPP_STORE"
fi

if [ "${UNIVERSAL:-0}" = "1" ]; then
    # shellcheck disable=SC2086 # SWIFT_FLAGS is a list of words
    swift build -c release $SWIFT_FLAGS --arch arm64 --arch x86_64
    # Asked rather than assumed: newer SwiftPM moved universal builds out of .build/apple, and a copy left
    # there by an older toolchain would otherwise be bundled instead.
    BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"
else
    # shellcheck disable=SC2086
    swift build -c release $SWIFT_FLAGS
    BINARY="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
# The packages' resources, such as the demo library's PDFs, are bundles beside the executable; Bundle.module looks
# for them in the app's Resources.
for bundle in "$(dirname "$BINARY")"/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/container-migration.plist "$APP/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Scrollkeeper</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.scooper4711.Scrollkeeper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Scrollkeeper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>io.github.scooper4711.Scrollkeeper.handoff</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>scrollkeeper</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>io.github.scooper4711.scrollkeeper.index</string>
            <key>UTTypeDescription</key>
            <string>Scrollkeeper Library List</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>scrollkeeperindex</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER:-$VERSION}</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Stephen Cooper. MIT License.</string>
</dict>
</plist>
PLIST

# The entitlements turn on the App Sandbox. A build signed with the team's Developer ID also joins the Tableside
# Toolkit's App Group, whose folder holds the downloads: the team's ID takes the place of TEAM_ID. The team ID is
# read from the signing certificate, or from TEAM_ID in the environment, and never committed. An ad hoc signature
# can't join the group, so its build leaves the group out and keeps the downloads in its own container.
ENTITLEMENTS="build/Scrollkeeper.entitlements"
if [ "${SIGNING_IDENTITY:-}" != "-" ]; then
    TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning \
        | sed -n 's/.*"Developer ID Application: .*(\([A-Z0-9]*\))"$/\1/p' | head -n 1)}"
fi
if [ -n "${TEAM_ID:-}" ]; then
    sed "s/TEAM_ID/$TEAM_ID/" Resources/Scrollkeeper.entitlements > "$ENTITLEMENTS"
else
    cp Resources/Scrollkeeper.entitlements "$ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$ENTITLEMENTS"
fi
scripts/sign-app.sh "$APP" "$ENTITLEMENTS"
echo "Built $APP ($VERSION)"

if [ "${CHANNEL:-}" = "appstore" ]; then
    # The App Store build has no updater and no outside payment link (guidelines 2.4.5(vii) and 3.1.1).
    if strings "$APP/Contents/MacOS/$EXECUTABLE" | grep -q -E "AppUpdater|ko-fi\.com"; then
        echo "The App Store build still contains the updater or the Ko-fi link." >&2
        exit 1
    fi
    # tabletop-kit's script comes with the package checkout; PACKAGER points elsewhere, to try a newer one.
    "${PACKAGER:-.build/checkouts/tabletop-kit/scripts/package-appstore.sh}" "$APP" "$ENTITLEMENTS" io.github.scooper4711.Scrollkeeper
fi
