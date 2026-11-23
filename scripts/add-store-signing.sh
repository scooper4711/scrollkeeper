#!/usr/bin/env bash
# On GitHub, loads the Mac App Store signing material and exports its paths and identities through GITHUB_ENV.
# Specified in docs/specs/app-store-pipeline. The secrets arrive as environment variables; none is printed.
set -euo pipefail

BUNDLE_ID=io.github.scooper4711.Scrollkeeper
KEYCHAIN="$RUNNER_TEMP/store-signing.keychain-db"
PROFILE="$RUNNER_TEMP/Scrollkeeper.provisionprofile"
KEY_FILE="$RUNNER_TEMP/AuthKey_$ASC_KEY_ID.p8"

fail() { echo "add-store-signing: $*" >&2; exit 1; }

import_certificate() {
    local file="$RUNNER_TEMP/certificate.p12"
    printf '%s' "$1" | base64 --decode > "$file"
    security import "$file" -k "$KEYCHAIN" -P "$2" -T /usr/bin/codesign -T /usr/bin/productbuild >/dev/null
    rm -f "$file"
}

add_keychain() {
    local password
    password="$(uuidgen)"
    security create-keychain -p "$password" "$KEYCHAIN"
    security set-keychain-settings -lut 21600 "$KEYCHAIN"
    security unlock-keychain -p "$password" "$KEYCHAIN"
    import_certificate "$APPLE_DISTRIBUTION_CERTIFICATE" "$APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD"
    import_certificate "$MAC_INSTALLER_CERTIFICATE" "$MAC_INSTALLER_CERTIFICATE_PASSWORD"
    security set-key-partition-list -S apple-tool:,apple:,codesign:,productbuild: -s -k "$password" "$KEYCHAIN" \
        >/dev/null
    # shellcheck disable=SC2046  # The existing keychains are one quoted path per line, without spaces.
    security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
}

add_profile() {
    local plist="$RUNNER_TEMP/profile.plist" expiry
    printf '%s' "$MAS_PROVISIONING_PROFILE" | base64 --decode > "$PROFILE"
    security cms -D -i "$PROFILE" > "$plist" || fail "MAS_PROVISIONING_PROFILE isn't a base64 provisioning profile"
    /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$plist" \
        | grep -q "\.$BUNDLE_ID$" || fail "the profile is for another app"
    expiry="$(plutil -extract ExpirationDate raw -o - "$plist")"
    [[ "$expiry" > "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ]] || fail "the profile expired on $expiry"
    rm -f "$plist"
}

add_api_key() {
    if [[ "$ASC_KEY" == *"BEGIN PRIVATE KEY"* ]]; then
        printf '%s\n' "$ASC_KEY" > "$KEY_FILE"
    else
        printf '%s' "$ASC_KEY" | base64 --decode > "$KEY_FILE"
    fi
    grep -q 'BEGIN PRIVATE KEY' "$KEY_FILE" || fail "ASC_KEY isn't a .p8 key"
    chmod 600 "$KEY_FILE"
}

identity() { security find-identity -v "$@" "$KEYCHAIN" | sed -nE 's/.*"(.*)"$/\1/p'; }

export_settings() {
    local app installer
    app="$(identity -p codesigning | grep '^Apple Distribution:' | head -n 1)"
    installer="$(identity | grep -E '^(3rd Party Mac Developer Installer|Mac Installer Distribution):' | head -n 1)"
    [[ -n "$app" ]] || fail "no Apple Distribution identity"
    [[ -n "$installer" ]] || fail "no Mac installer identity"
    {
        echo "APP_SIGNING_IDENTITY=$app"
        echo "INSTALLER_IDENTITY=$installer"
        echo "TEAM_ID=$(printf '%s' "$app" | sed -E 's/.*\(([A-Z0-9]{10})\)$/\1/')"
        echo "PROVISIONING_PROFILE=$PROFILE"
        echo "ASC_KEY_FILE=$KEY_FILE"
    } >> "$GITHUB_ENV"
}

add_keychain
add_profile
add_api_key
export_settings
