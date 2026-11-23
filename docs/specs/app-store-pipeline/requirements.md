# Mac App Store pipeline: requirements

- R1 A manual run on `main` or a `v*` tag builds the Mac package on a GitHub-hosted runner, so signing secrets never
  reach the `mac-mini` runner.
- R2 The run stops unless its commit is on `origin/main`, the tree is clean, and a tag matches `scripts/version.sh`.
- R3 Tests pass before any signing material is loaded.
- R4 The package is universal, carries the commit's build number, and is signed for the App Store.
- R5 The default run validates with App Store Connect. Only `upload: true` uploads, and it uploads the file built in
  that run.
- R6 Only `internal_testers: true` distributes, and only to internal TestFlight groups, with a What to Test note. The
  run never adds a build to an external group or submits for review. Those stay manual in App Store Connect.
- R7 The run summary records the commit, Xcode version, version, build number and package SHA-256.
- R8 The same run archives the iPad app from the same commit with the same version and build number, signs it with the
  App Store Connect API key, and validates it. `upload: true` uploads that `.ipa` too, only if both builds validated.
- R9 The signing secrets are `app-store` Environment secrets, so only `main` and `v*` tags can read them.
