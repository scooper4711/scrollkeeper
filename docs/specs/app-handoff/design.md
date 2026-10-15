# App Handoff — Design

## Overview

The contract between Scrollkeeper and a requesting app is a small JSON file
and a URL. Requesting apps do not link `ScrollkeeperKit`; credentials,
downloads and the Paizo rate limits stay inside Scrollkeeper.

```
Mapsmith                     Scrollkeeper
 search ── reads ──▶ Application Support/Scrollkeeper/Shared/maps.json
 pick   ── opens ──▶ scrollkeeper://open?sku=PZO31005&app=mapsmith
                      → find the title, pick the edition
                      → download through the queue when missing or outdated
                      → NSWorkspace.open(files, withApplicationAt: Mapsmith)
```

This document is the source of truth for both formats. Mapsmith's design
refers here.

## Map index (`Sharing/MapIndex.swift`)

```json
{
  "formatVersion": 1,
  "generatedAt": "2026-10-15T18:00:00Z",
  "titles": [
    { "sku": "PZO31005", "title": "Pathfinder Flip-Mat Classics: Forest",
      "series": "Flip-Mat Classics", "number": null }
  ]
}
```

- `MapIndex.make(from:)` keeps titles whose `classification.productLine` is
  `.maps` and that have a quick-downloadable edition (`Edition.isQuickDownloadable`),
  sorted by `titleSortKey`. `series` is omitted when empty.
- `LibraryStore.writeMapIndexIfChanged()`, called from `rebuildItems()`,
  compares the new entries with those it last wrote; when they differ it
  queues an atomic write through the store's `persist` queue. Nothing is
  written while the catalog is empty, so Mapsmith can tell "not synced yet"
  from "no maps".
- The location is defined once, `MapIndex.fileName` under
  `LibraryEnvironment.sharedDirectory` (`<dataDirectory>/Shared`). In demo
  mode the data folder is temporary, so demo titles never reach Mapsmith.
- Dates are encoded as ISO 8601; keys are stable and new fields may be added
  without a version change. A change that breaks readers raises
  `formatVersion`.

## Open request (`Sharing/HandoffRequest.swift`)

`HandoffRequest(url:)` parses the URL and throws `HandoffError` for anything
other than scheme `scrollkeeper`, host `open`, a non-empty `sku` and a known
`app`. `HandoffApp` is the allowlist: each case carries the bundle identifier
to open the files with and the file types it accepts.

| Key | Bundle identifier | Accepts |
|---|---|---|
| `mapsmith` | `com.github.scooper4711.Mapsmith` | PDF, images |

## Resolving a request (`Store/LibraryStore+Handoff.swift`)

`handoffFiles(for:) async throws -> [URL]`:

1. A link can arrive while the app is starting, so it first waits for
   `isLoaded` (set by `start()` once the stored catalog and account are read).
   Signed out → `HandoffError.signedOut`. Unknown SKU → `.titleNotFound`.
2. `handoffTarget(for:)` takes the quick action's `open` target unless it is
   outdated, else its `download` target; neither → `.noEdition`.
3. When the target is missing or outdated it calls `download(_:)` and waits:
   while the target's state is pending it awaits the target's own task, or any
   running task while it waits its turn. A `.failed` or `.interrupted` state
   afterwards → `.downloadFailed`; cancelled → `.cancelled`.
4. `files(in:)` filtered to the app's accepted types; none → `.noAcceptedFiles`.

## App glue (macOS, `ScrollkeeperUI`)

- `scripts/build-app.sh` declares the `scrollkeeper` URL scheme in
  `CFBundleURLTypes`.
- The library window has `.onOpenURL`, and `.handlesExternalEvents` keeps the
  request in the open window instead of opening another.
- `HandoffHandler`, a view modifier on the library window, selects the title, awaits `handoffFiles`, looks up the
  requesting app with `NSWorkspace.urlForApplication(withBundleIdentifier:)`
  and opens the files with it. Failures become an alert on the window.

## Sandboxing

Neither app is sandboxed. If they become sandboxed, the URL handoff and the
file opening keep working: Launch Services gives the receiving app access to
the files it is asked to open. Reading `maps.json` from Scrollkeeper's folder
does not. The index then moves to an App Group container shared by the
Tableside Toolkit apps (`containerURL(forSecurityApplicationGroupIdentifier:)`),
which needs a Developer ID team signature and entitlements in both build
scripts. Only `LibraryEnvironment.sharedDirectory` and Mapsmith's matching
default location change.
