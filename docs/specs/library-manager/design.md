# Scrollkeeper — Design

## Overview

A Swift package with three targets, plus an Xcode project for the iPad app:

| Target | Kind | Contents |
|---|---|---|
| `ScrollkeeperKit` | library | Models, Paizo clients, sync, classification, persistence, downloads, the observable `LibraryStore`. Fully unit tested. Builds for macOS and iPadOS. |
| `ScrollkeeperUI` | library | SwiftUI views and the `App` itself. They render `LibraryStore` state and forward user actions to it. Builds for macOS and iPadOS; the few differences are behind `#if os(...)`. |
| `Scrollkeeper` | executable | The macOS entry point: one file that starts the shared `App`. |

`scripts/build-app.sh` wraps the macOS executable in an ad-hoc signed `.app`
bundle. `ios/Scrollkeeper.xcodeproj` builds the iPad app from the same
package: its only source file starts the shared `App`.

The package depends on ZIPFoundation for unpacking archives, because iPadOS has
no command-line tools to call.

### Platform differences

| | Mac | iPad |
|---|---|---|
| Downloads folder | `~/Library/Application Support/…/Files`, changeable | the app's Documents folder, shown in the Files app |
| Open | default application (`NSWorkspace`) | Quick Look preview in the app |
| Other applications | "Open With" menu | share sheet |
| Zips the app does not keep | save panel, downloaded straight to the chosen place | downloaded to a temporary folder, then the share sheet |
| File tags | Finder tags, both directions | none; tags live in the app |
| Settings | Settings window | sheet opened from the toolbar |

## How the Paizo library works

These facts were established by observing the web library. None of it is a
documented API, so every step is isolated behind a small client type.

### Sign-in (store.paizo.com, BigCommerce)

1. `GET /login.php` to obtain session cookies.
2. `POST /login.php?action=check_login` with form fields `login_email` and
   `login_pass`. Success redirects to `/account.php…`; failure returns to
   `/login.php`.
3. `GET /customer/current.jwt?app_client_id=<appId>` returns a JSON Web Token
   that identifies the customer to the library app. The app id is published in
   the HTML of `/library/`.

The token behaves in ways that shaped `PaizoSession`:

- It is valid for 15 minutes, and the store hands out the **same** token to
  every request, from every session of that customer, until it has expired.
  Only then is the next one issued. A token can therefore arrive with seconds
  left to live, and signing in again does not produce a newer one.
- The library app answers a request that carries an expired token with a
  server error (status 500 or 501), not with an authentication error.
- A store session can end without notice; a token request on an ended session
  is answered with 404, and signing in again restores it. What ends a session
  is not known. Using the web library in a browser alongside the app does not:
  signing in, browsing, refreshing and downloading in both, in turn, works.

`PaizoSession` therefore reads the expiry from the token itself, stops using a
token 45 seconds before it lapses, and when the store returns one that is about
to lapse it waits until it has and asks again. A token request that fails is
followed by a new sign-in.

### Catalog (app.paizo.com, Next.js)

- `GET /customer-library?token=<jwt>&page=<n>` renders one page of 50
  entitlements, newest first. The data is embedded in the page as React Server
  Component "flight" chunks: `self.__next_f.push([1,"…"])`. Concatenating the
  chunks gives newline-separated rows; the row whose value is an array with an
  `entitlements` property carries `entitlements`, `count` and `tokenExpired`.
- A page takes about 15 seconds to render regardless of load, and pages can be
  requested in parallel. The sync therefore fetches page 1 to learn the count
  and then fetches the remaining pages six at a time.
- `GET /api/library/entitlement/customer/<packageId>?token=<jwt>` returns one
  entitlement as `{data: {…}}` in under a second: its `DigitalPackage` carries
  `DateLastUpdated`, `File`, `Filepath` and the individual files of the
  package. An unknown id is answered with status 500. The app uses it to check
  for updated files (see "Checking for updated files"); it does not use the
  individual files, since an archive is downloaded whole and unpacked.
- `GET /api/library/entitlement/customer?token=<jwt>&page=<n>` returns the same
  50 entitlements as the page, as JSON, and takes as long. It ignores requests
  for a larger page. The app does not use it.

### Downloads

1. `POST /api/library/download` with JSON `{key, legacy, token, customer}`
   returns `{data: <ticket>}`.
   - New storage: `key` is the package's `File`, `legacy` is `"false"`.
   - Old storage (file path contains `com.paizo.downloads.raw/`): `key` is the
     percent-decoded path after that marker, `legacy` is `"true"`.
2. `GET /api/library/download/<ticket>?token=<jwt>` returns `{data: <url>}`, a
   signed S3 URL that is downloaded without further authentication.

The web library also records a "last downloaded" date on the account after a
download. The app does not, so that it never writes to the account.

### Storefront metadata (store.paizo.com GraphQL)

The storefront home page embeds an anonymous GraphQL token. With it,
`POST /graphql` answers product queries by SKU: name, description, default
image, brand, category breadcrumbs and custom fields. Queries are limited by a
complexity budget; ten products per request fits.

## Components

```
Views ──► LibraryStore ──► CatalogSynchronizer ──► LibraryCatalogClient ─┐
              │                    │                                     ├─► PaizoSession ─► HTTPClient
              │                    └─────────────► StorefrontClient ─────┘
              ├──► FileLocator, ArchiveExtractor, FinderTagger
              ├──► LibraryRepository (JSON files)
              ├──► CredentialStore (Keychain)
              └──► LibraryQuery, EntitlementGrouper, Classifier (pure)
```

### Networking

- `HTTPClient` — protocol with `send(_:)` and `download(_:to:progress:)`.
  `URLSessionHTTPClient` is the production implementation; tests use a stub.
- `PaizoSession` — actor. Signs in and hands out customer tokens, reusing one
  until shortly before the expiry it carries.
- `FlightPayloadParser` — extracts the `LibraryPage` from library page HTML.
  It scans for the chunk string literals rather than matching them with a
  regular expression: a single chunk can be several hundred kilobytes, which
  the regular expression engine gives up on without reporting an error.
- `LibraryCatalogClient` — pages and download URL signing.
- `StorefrontClient` — anonymous token and batched product metadata.

### Catalog model

- `Entitlement` — decoded leniently from Paizo's JSON; unknown or missing
  fields never fail the page.
- `EntitlementGrouper` — groups entitlements into `LibraryTitle`s by SKU. The
  SKU is `ProvidedByProductSku`, else the embedded product's SKU, else the
  package's first product SKU; the literal `undefined` counts as missing.
- `EditionKind` — parsed from the entitlement name, tolerant of the spelling
  variants found in the data ("File Per Chapter", "File per Chatper",
  "Singel File", "(Single-File)").
- `Classifier` — pure function of title, SKU and storefront metadata producing
  a `Classification`. `LevelRangeParser` reads level ranges from summaries.
- The title and download folder name are derived from entitlement data only,
  never from storefront metadata, so that paths stay stable when metadata
  arrives later.

### Sync

`CatalogSynchronizer` runs one sync and reports `SyncEvent`s through a callback:

- **Full**: page 1, then all remaining pages with six concurrent requests.
- **Refresh**: pages in order, stopping at the first page that contains no
  unknown entitlement.
- Each page is tried twice. A token reported as expired is renewed once, and a
  download request that fails with a server error is repeated once with a
  renewed token.

`MetadataSynchronizer` fetches storefront metadata for a batch of ten SKUs and
downloads each cover into the cover cache. `LibraryStore` queues the SKUs that
have no metadata as each page arrives and works through the queue in the
background, so artwork fills in while the catalog is still loading.

### Persistence

`LibraryRepository` reads and writes JSON files in
`~/Library/Application Support/Scrollkeeper/`:

| File | Contents |
|---|---|
| `catalog.json` | entitlements |
| `metadata.json` | storefront metadata by SKU |
| `userdata.json` | tags by title id |
| `updatechecks.json` | when each edition was last checked for an update |
| `Covers/<sku>.jpg` | cover artwork |

Titles are derived from these at load time, so improving the classifier never
needs a migration. Classifying a few thousand titles takes a few hundred
milliseconds, so rebuilds reuse every title whose entitlements, metadata and
tags are unchanged.

### Downloads

`LibraryStore` asks `LibraryCatalogClient` for a signed URL and downloads to
`<path>.download`. `FileLocator` decides the final path:

- a plain file goes to `<download folder>/<title>/<edition name>.<ext>`;
- a zip of documents (`Edition.isUnpackedArchive`) is unpacked by `ArchiveExtractor` (the system's
  `ditto`) into `<download folder>/<title>/<edition name>/` and the zip is
  removed. The folder only appears once unpacking has finished, and the
  upload identifiers Paizo prefixes to file names are stripped;
- a zip whose name marks it as an asset pack (`Edition.isSavedElsewhere`:
  community use, JPG or PNG sets, logos, icons, audio) is downloaded to a
  location the user picks in a save panel (`LibraryStore.export`) and is not
  tracked afterwards.

Paizo's download API reads the members of the request body by position, so
the body is written with its members in the order the web library uses:
`key`, `legacy`, `token`, `customer`.

A file counts as downloaded when it exists at that path, so there is no
separate download database to fall out of step. For the same reason the time of
a download is the creation date of the file (or of an archive's folder); a
download is out of date when the entitlement's update date is later than that.

The web library offers a "last updated" sort order (`sort=updated-desc`), but
the pages it returns are not in order of the update date in the data, so it
cannot be used to find recently updated files. Checked again in October 2026:
of the first 100 entitlements in that order 15 had an update date, out of
order, while the library held 270 dated ones; ascending and descending gave
nearly the same page. The category and game filters do not help either: only
some updated files carry them.

### Checking for updated files

Since the list cannot say what changed, the app asks about one edition at a
time (`LibraryCatalogClient.fetchFileStatus`), which costs Paizo about a
fifteenth of a library page. `UpdateCheckPolicy` decides what to ask and holds
every number as a named constant:

| Constant | Value | Meaning |
|---|---|---|
| `dailyLookups` | 50 | lookups allowed in any 24 hours |
| `concurrentLookups` | 2 | lookups in flight at once |
| `minimumInterval` | 1 day | an edition is not asked about more often |
| `recentInterval` / `olderInterval` | 7 / 30 days | how often an edition is due |
| `recentAge` | 1 year | what counts as a recent edition |
| `listingThreshold` | 900 | downloaded editions above which the list is cheaper |
| `listingInterval` | 30 days | time between full syncs made for this reason |
| `listingConcurrentPages` | 2 | pages at once in such a sync |

The policy is a pure function of the downloaded editions, the log and the
time. It ranks editions by how overdue they are relative to their own interval
(never checked first), so one rule gives every case: a small library is checked
daily, a larger one in rotation with recent editions about four times as often
as older ones. The threshold is where the two costs meet: 900 lookups of about
a second against 61 pages of about fifteen.

`UpdateCheckLog` (`updatechecks.json`) records when each edition was last
checked and when the library was last listed in full. The allowance is counted
from it: the lookups logged in the last 24 hours. A check on opening a title
is not held back by the allowance but counts toward it.

`FileStatusFetcher` runs the lookups and stops at the first failure, returning
what it learned. `LibraryStore+UpdateChecks` applies the results to the
entitlements (update date, file name and path), which makes the existing
out-of-date logic show the badge.

`LibraryStore.download` keeps the order downloads were asked for. Five run at a
time; the rest are `waiting` and start as running ones finish. `downloadJobs`
is what the downloads list shows.

The app uses an ordinary `URLSession`, not a background one, so iPadOS cuts its
downloads off when it suspends the app. Three things soften that:
`DownloadContinuity` asks for background time when the scene goes to the
background with downloads pending; `URLSessionHTTPClient` keeps the resume data
of a download that was cut off and continues from it on the next attempt for
the same destination, starting over if the server refuses; and
`LibraryStore.resumeInterruptedDownloads` restarts interrupted downloads when
the scene becomes active. A background `URLSession` would let long downloads
finish while the app is suspended, at the cost of delegate-based plumbing and
relaunch handling; it has not been needed so far.

`LibraryStore.quickActions(for:)` decides what the hover buttons and the
right-click menu offer for a title. It ranks the editions by
`Edition.downloadPreference` and looks at what is on disk.

Opening is done by the views with `NSWorkspace`: "Open" uses the default
application, "Open With" lists `urlsForApplications(toOpen:)`.

### Tags

`FinderTagger` reads and writes `URLResourceKey.tagNamesKey`. `LibraryStore`
writes a title's tags to its downloaded files whenever the tags change or a
download finishes, and merges tags found on files into the title at load.

### Credentials

`KeychainCredentialStore` stores one internet-password item for
`store.paizo.com`. The app is not associated with the paizo.com domain, so it
cannot read the Passwords app's entry for the site directly; instead the
Settings fields declare username and password content types, which lets the
user fill them with Password AutoFill.

### App updates

`AppUpdater` reads `releases/latest` from GitHub's API, which leaves out drafts
and pre-releases, and compares the tag with the bundle version as `AppVersion`s
(numbers only, so `v0.10.0` is newer than `0.9.3`). A newer release moves it to
the `available` state and nothing more; `startDownload` fetches the asset whose
name ends in `.dmg` into the Downloads folder. `UpdatePrompt` shows each state as
an alert on the Mac.

### Views

- `LibraryWindow` — `NavigationSplitView`: sidebar of filters, content in the
  chosen view mode, detail pane.
- `CoverGridView`, `TitleListView`, `TitleTableView` — the three view modes.
- `TitleDetailView` — cover, summary, metadata, editions and their files, tags.
- `SyncStatusBar` — progress bars for catalog and artwork.
- `SettingsView` — credentials and download folder.

## Testing

`ios/UITests` holds XCUITest cases that drive the iPad app in a simulator. They
launch it in demo mode (`LibraryEnvironment.demo`, backed by `DemoHTTPClient`
and `DemoCatalog`), which goes through the same sign-in, sync and download code
as the real thing. They exist because some faults only show in the running app:
a toolbar button drawn with an overlay looked normal on iPadOS 26 but no longer
received its taps, which no unit test could have caught.

Unit tests use Swift Testing. Network types are tested against a stub
`HTTPClient` with fixtures modeled on real responses but containing no account
data. `URLSessionHTTPClient` is tested through a `URLProtocol` stub.
`scripts/coverage.sh` fails when line or region coverage of `ScrollkeeperKit`
is below 80%. Swift's coverage tooling does not report branch coverage; region
coverage is the closest measure and is used in its place.

SwiftUI view declarations are not unit tested and are not part of the measured
target.
