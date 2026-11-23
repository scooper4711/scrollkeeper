# App Store pipeline: design

`.github/workflows/appstore.yml` runs by hand only, so a pushed tag or scheduled job can't send a build to Apple. It
checks out tabletop-kit's pipeline scripts at a pinned commit; their design is in tabletop-kit's
`docs/specs/app-store-pipeline`.

- `check-store-release.sh` holds the release guards (R2) and, after the build, the package checks (R4).
- `add-store-signing.sh` loads the certificates into a temporary keychain, and writes the provisioning profile and API
  key to the runner's temporary folder.
- `make appstore` packages through the pinned `package-appstore.sh`. `VALIDATE=1` validates, and a separate step uploads
  that same file.
- `make ipad-archive` archives through tabletop-kit's `archive-ios.sh` (R8). The team comes from the Apple Distribution
  certificate and goes in the ignored `ios/Local.xcconfig`. Xcode's automatic signing needs an Admin API key, because
  the hosted runner has no Xcode account. `altool` validates the `.ipa` before any upload starts.
- `testflight-internal.rb` sets the note and delivers to groups Apple marks internal (R6).
