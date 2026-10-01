# Paizo Library Manager — Design

## Overview

A Swift package with two targets:

| Target | Kind | Contents |
|---|---|---|
| `PaizoLibraryKit` | library | Models, Paizo clients, sync, classification, persistence, downloads, the observable `LibraryStore`. Fully unit tested. |
| `PaizoLibraryManager` | executable | SwiftUI views only. They render `LibraryStore` state and forward user actions to it. |

`scripts/build-app.sh` wraps the executable in an ad-hoc signed `.app` bundle.
The package has no third-party dependencies.

## How the Paizo library works

These facts were established by observing the web library. None of it is a
documented API, so every step is isolated behind a small client type.

### Sign-in (store.paizo.com, BigCommerce)

1. `GET /login.php` to obtain session cookies.
2. `POST /login.php?action=check_login` with form fields `login_email` and
   `login_pass`. Success redirects to `/account.php…`; failure returns to
   `/login.php`.
3. `GET /customer/current.jwt?app_client_id=<appId>` returns a JSON Web Token
   that identifies the customer to the library app. It is valid for 15 minutes.
   The app id is published in the HTML of `/library/`.

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
  entitlement with `DigitalPackage.AssetsData`: the individual files of the
  package (the chapters). It answers in about a second and is called only when
  the user asks for the chapters of an edition.

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
              ├──► DownloadManager ──► LibraryCatalogClient, HTTPClient, FinderTagger
              ├──► LibraryRepository (JSON files)
              ├──► CredentialStore (Keychain)
              └──► LibraryQuery, EntitlementGrouper, Classifier (pure)
```

### Networking

- `HTTPClient` — protocol with `send(_:)` and `download(_:to:progress:)`.
  `URLSessionHTTPClient` is the production implementation; tests use a stub.
- `PaizoSession` — actor. Signs in and hands out customer tokens, reusing one
  for ten minutes.
- `FlightPayloadParser` — extracts the `LibraryPage` from library page HTML.
- `LibraryCatalogClient` — pages, package details and download URL signing.
- `StorefrontClient` — anonymous token and batched product metadata.

### Catalog model

- `Entitlement` — decoded leniently from Paizo's JSON; unknown or missing
  fields never fail the page.
- `EntitlementGrouper` — groups entitlements into `LibraryItem`s by SKU. The
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
- Each page is tried twice. A token reported as expired is refreshed once.

`MetadataSynchronizer` fetches storefront metadata for SKUs that have none, in
batches of ten, then downloads each cover into the cover cache. It is started
for every page as it arrives, so artwork fills in while the catalog is still
loading.

### Persistence

`LibraryRepository` reads and writes JSON files in
`~/Library/Application Support/Paizo Library Manager/`:

| File | Contents |
|---|---|
| `catalog.json` | entitlements |
| `metadata.json` | storefront metadata by SKU |
| `userdata.json` | tags by title id |
| `Covers/<sku>.jpg` | cover artwork |

Titles are derived from these at load time (grouping and classification of
3,000 entitlements takes milliseconds), so improving the classifier never needs
a migration.

### Downloads

`DownloadManager` signs the URL, downloads to a temporary file and moves it to
`<download folder>/<title>/<edition name>.<ext>`; chapters go into a
`Chapters` subfolder. A file counts as downloaded when it exists at that path,
so there is no separate download database to fall out of step.

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

### Views

- `LibraryWindow` — `NavigationSplitView`: sidebar of filters, content in the
  chosen view mode, detail pane.
- `CoverGridView`, `TitleListView`, `TitleTableView` — the three view modes.
- `TitleDetailView` — cover, summary, metadata, editions, chapters, tags.
- `SyncStatusBar` — progress bars for catalog and artwork.
- `SettingsView` — credentials and download folder.

## Testing

Unit tests use Swift Testing. Network types are tested against a stub
`HTTPClient` with fixtures modelled on real responses but containing no account
data. `URLSessionHTTPClient` is tested through a `URLProtocol` stub.
`scripts/coverage.sh` fails when line or region coverage of `PaizoLibraryKit`
is below 80%. Swift's coverage tooling does not report branch coverage; region
coverage is the closest measure and is used in its place.

SwiftUI view declarations are not unit tested and are not part of the measured
target.
