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
| `mapsmith` | `io.github.scooper4711.Mapsmith` | PDF, images |
| `pluck` | `io.github.scooper4711.pluck` | PDF |
| `fieldguide` | `io.github.scooper4711.FieldGuide` | PDF |

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
- The Mac `AppDelegate` owns the `LibraryStore`, starts it at launch and takes
  the links in `application(_:open:)`, so a request is answered whether or not
  a library window is open, including the one that launched the app. The
  window group has `.handlesExternalEvents(matching: [])`, so SwiftUI opens no
  window for a link (it would otherwise open a second window when a link
  launches the app, and drop a link that arrives before the window exists).
- `HandoffCoordinator` handles each link: it sends an index request's file to
  the app with `handoffIndex`; for other requests it asks for the title to be
  selected (open requests only), awaits `handoffFiles`, looks up the
  requesting app with `NSWorkspace.urlForApplication(withBundleIdentifier:)`
  and opens the files with it. `HandoffHandler`, a view modifier on the library
  window, selects the title and shows failures as an alert.

## Sandboxing

All the Tableside Toolkit apps run in the App Sandbox. The URL handoff and the
file opening work there: Launch Services gives the receiving app access to the
files it is asked to open. That is why a sandboxed app gets its list as a
title index handed over by an index request, not by reading `maps.json` from
Scrollkeeper's folder, which it cannot. `maps.json` is still written, but
Mapsmith 1.1 and earlier, which read it from outside the sandbox, no longer
find it once Scrollkeeper's data folder moves into its container; it can go.

`Resources/Scrollkeeper.entitlements` turns on the sandbox, network access
(paizo.com, covers, the update check), read-write access to a folder the user
picks and its app-scoped bookmark, the Downloads folder (where the updater
saves the new disk image) and the App Group below.

### Shared download folder (requirements 5)

The apps that import many titles at once read Scrollkeeper's downloads
directly; asking for each title through the handoff would be too slow for
them. In the sandbox that needs a folder both sides may reach:

- **App Group.** Scrollkeeper, Pawn Shop, Field Guide and Turnkeeper get the
  `com.apple.security.application-groups` entitlement for one group,
  `<team ID>.io.github.scooper4711.tableside`. On the Mac the identifier must
  start with the team ID, and the apps must be signed by that team; an
  ad-hoc-signed app is refused or prompts for access to other apps' data. The
  team ID is not committed: the entitlements say `TEAM_ID`, and
  `scripts/build-app.sh` puts in the team of the Developer ID certificate in
  the keychain (or `TEAM_ID` from the environment). An ad hoc build
  (`SIGNING_IDENTITY=-`, or no certificate) leaves the group out.
- **Finding the group.** `SharedDownloadFolder.url()` reads the groups from the
  app's own entitlements (`SecTaskCopyValueForEntitlement`), so the code needs
  no team ID either, picks the one ending in `.io.github.scooper4711.tableside`
  and asks `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`
  for `~/Library/Group Containers/<group>/`. Downloads go to its
  `Scrollkeeper/Files/`. With no group (an ad hoc build, the tests, the iPad)
  it returns nil and `LibraryEnvironment.live()` keeps `<data folder>/Files`.
- **Moving the downloads.** `container-migration.plist` moves
  `${ApplicationSupport}/Scrollkeeper` and the preferences into Scrollkeeper's
  own container at the first sandboxed launch. `live()` then asks
  `DownloadFolderMove.defaultFolder(legacy:shared:)` for the default folder: when
  `<data folder>/Files` holds files and the shared folder holds none (hidden
  files aside), it renames the one to the other with `FileManager.moveItem`.
  Both moves are renames on the same volume, so a library of several
  gigabytes moves at once. If the move fails, the old folder stays the
  default download folder; once the shared folder has files, the old one is
  left alone.
- **Chosen folder.** A folder the user chose is kept as a security-scoped
  bookmark (`ChosenDownloadFolder`, 5.4a of the library-manager requirements),
  made while the app still runs outside the sandbox, so it stays reachable
  after the switch.
- **Readers.** Each importing app looks for `Scrollkeeper/Files` in the group
  container first and keeps its folder picker, with a remembered bookmark, as
  the fallback (5.5). Readers never write there.
