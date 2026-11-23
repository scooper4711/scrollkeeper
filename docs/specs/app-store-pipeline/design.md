# Mac App Store pipeline: design

`.github/workflows/appstore.yml` runs by hand only, so a pushed tag or scheduled job can't send a build to Apple.

- `scripts/check-store-release.sh` holds the release guards (R2) and, after the build, the package checks (R4).
- `scripts/add-store-signing.sh` loads the Apple Distribution and installer certificates into a temporary keychain,
  and writes the provisioning profile and API key to the runner's temporary folder. It rejects an expired profile or
  one for another app.
- `make appstore` packages through tabletop-kit's `package-appstore.sh`. `VALIDATE=1` validates, and a separate step
  uploads that same file. Neither adds the build to a TestFlight group (R6).

- `make ipad-archive` archives through tabletop-kit's `archive-ios.sh` (R8). The team comes from the Apple Distribution
  certificate and goes in the ignored `ios/Local.xcconfig`. Xcode's automatic signing needs an Admin API key, because
  the hosted runner has no Xcode account. `altool` validates the `.ipa` before any upload starts.

These scripts live here for the pilot. They move to tabletop-kit when a second app adopts them.
