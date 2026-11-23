# Mac App Store pipeline: requirements

- R1 A manual run on `main` or a `v*` tag builds the Mac package on a GitHub-hosted runner, so signing secrets never
  reach the `mac-mini` runner.
- R2 The run stops unless its commit is on `origin/main`, the tree is clean, and a tag matches `scripts/version.sh`.
- R3 Tests pass before any signing material is loaded.
- R4 The package is universal, carries the commit's build number, and is signed for the App Store.
- R5 The default run validates with App Store Connect. Only `upload: true` uploads, and it uploads the file built in
  that run.
- R6 The run never distributes to testers or submits for review. Those stay manual in App Store Connect.
- R7 The run summary records the commit, Xcode version, version, build number and package SHA-256.
