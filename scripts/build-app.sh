#!/bin/sh
# Builds "build/Scrollkeeper.app" from the Swift package.
#
# VERSION    version written to the bundle (default 0.0.0)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
# TEAM_ID    the team that owns the App Group (default: read from the Developer ID certificate)
# SIGNING_IDENTITY  passed to scripts/sign-app.sh; "-" signs ad hoc, without the App Group
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
APP="build/Scrollkeeper.app"
EXECUTABLE="Scrollkeeper"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    # Asked rather than assumed: newer SwiftPM moved universal builds out of .build/apple, and a copy left
    # there by an older toolchain would otherwise be bundled instead.
    BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"
else
    swift build -c release
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
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Not published, endorsed, or specifically approved by Paizo.</string>
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
