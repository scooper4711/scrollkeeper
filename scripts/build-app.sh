#!/bin/sh
# Builds "build/Paizo Library Manager.app" from the Swift package.
#
# VERSION    version written to the bundle (default 0.0.0)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
APP="build/Paizo Library Manager.app"
EXECUTABLE="PaizoLibraryManager"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BINARY=".build/apple/Products/Release/$EXECUTABLE"
else
    swift build -c release
    BINARY="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Paizo Library Manager</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.scooper4711.PaizoLibraryManager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Paizo Library Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
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
    <string>Unofficial. Not affiliated with Paizo Inc.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally; Gatekeeper will still ask on other Macs.
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION)"
