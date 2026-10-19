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
      "series": "Flip-Mat Classics", "number": null, "downloaded": false }
  ]
}
```

- `MapIndex.make(from:)` keeps titles whose `classification.productLine` is
  `.maps` and that have a quick-downloadable edition (`Edition.isQuickDownloadable`),
  sorted by `titleSortKey`. `series` is omitted when empty.
- `downloaded` is true when the title is in `downloadedItemIDs` and not in
  `outdatedItemIDs`: then an open request needs no download.
- `LibraryStore.writeMapIndexIfChanged()`, called from `refreshDownloadedItems()`
  (which runs after every rebuild and every finished download),
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
other than scheme `scrollkeeper`, a host naming a `HandoffAction` (`open`,
`download` or `index`), a non-empty `sku` (except for `index`) and a known `app`. `HandoffApp` is the allowlist: each case carries the bundle identifier
to open the files with and the file types it accepts.

| Key | Bundle identifier | Accepts |
|---|---|---|
| `mapsmith` | `com.github.scooper4711.Mapsmith` | PDF, images |
| `pluck` | `io.github.scooper4711.pluck` | PDF |

`HandoffApp.canOpen(_:)` says whether an edition's download suits the app: a
file of an accepted type, or a zip of documents.

## Title index (`Sharing/TitleIndex.swift`)

The format of the map index, with a `kind` (the product type's label) on each
entry. `HandoffApp.lists(_:)` picks the titles an app lists: maps for Mapsmith,
every title for Pluck. `handoffIndex(for:)` waits for `isLoaded`, refuses with `.noCatalog`
while there are no titles, writes `TitleIndex.entries(from:downloaded:for:)`
to `LibraryEnvironment.titleIndexURL(for:)` and returns it; a failed write is
`.indexNotWritten`. `scripts/build-app.sh` exports the file's type in
`UTExportedTypeDeclarations`.

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
4. `HandoffApp.filesToSend(from:)` over `files(in:)`: the accepted types, and
   of those only the PDFs when there are any; none → `.noAcceptedFiles`.

## Status (`Sharing/HandoffStatus.swift`)

`HandoffApp.statusScheme` names the scheme an app takes status links in (`pluck`,
`mapsmith`). `HandoffStatus` (`downloading(fraction)`,
`failed(reason)`, `done`) builds the link; `HandoffStatusThrottle` lets through a
changed state or a whole-percent step; `LibraryStore.handoffStatus(for:)` reads
the state of the download the request waits for. While `handoffFiles` waits,
`HandoffHandler` polls it every 250 ms and opens each link through
`NSWorkspace` with `activates = false`.

## App glue (macOS, `ScrollkeeperUI`)

- `scripts/build-app.sh` declares the `scrollkeeper` URL scheme in
  `CFBundleURLTypes`.
- The library window has `.onOpenURL`, and `.handlesExternalEvents` keeps the
  request in the open window instead of opening another.
- `HandoffHandler`, a view modifier on the library window, sends an index
  request's file to the app with `handoffIndex`; for other requests it selects
  the title (open requests only), awaits `handoffFiles`, looks up the
  requesting app with `NSWorkspace.urlForApplication(withBundleIdentifier:)`
  and opens the files with it. Failures become an alert on the window.

## Sandboxing

Pluck is sandboxed; Scrollkeeper and Mapsmith are not yet. The URL handoff and
the file opening work in the sandbox: Launch Services gives the receiving app
access to the files it is asked to open. That is why a sandboxed app gets its
list as a title index handed over by an index request, not by reading
`maps.json` from Scrollkeeper's folder, which it cannot. Mapsmith now uses
the same request. `maps.json` is still written for Mapsmith 1.1 and earlier,
and can go once those versions are no longer in use.
