# Paizo Library Manager

A native app for the Mac and the iPad for browsing and downloading the digital
library attached to your [paizo.com](https://store.paizo.com) account.

Paizo's web library is slow to load and slow to search. This app downloads the
list of everything you own once, keeps it on your Mac, and gives you instant
search, sorting, filtering, cover artwork, summaries and tags.

This is an unofficial tool. It is not affiliated with or endorsed by Paizo Inc.
It only accesses files that your own account is entitled to download.

## Features

- Signs in with your Paizo account; credentials are kept in the macOS Keychain
  and the sign-in fields support Password AutoFill from the Passwords app.
- Downloads your full list of titles with a progress bar, and fetches cover
  artwork and summaries from the public storefront at the same time.
- Groups the different editions of a product (single file, file per chapter,
  lite versions) into one title. PDF editions that Paizo delivers as a zip are
  unpacked for you, so you get the chapters rather than an archive.
- Three ways to browse: cover thumbnails, a list, and a sortable column view.
- Search, plus filtering by game system, product type, level, format and tag.
- Automatic classification: adventure paths, stand-alone adventures, society
  scenarios (with season or year), maps, rulebooks, fiction and more.
- Tags that are written to the downloaded files as Finder tags.
- Downloaded files are kept on disk and can be opened straight from the app,
  with the default application or any other that handles the file type.

## Requirements

- macOS 14 or later, or iPadOS 17 or later
- Xcode 16 or later (Swift 6 toolchain) to build; for the iPad app, Xcode's iOS
  platform component as well (Xcode › Settings › Components)

## Building

```sh
make app      # builds build/Paizo Library Manager.app
make run      # builds and launches the app
make test     # runs the unit tests
make lint     # runs SwiftLint
make coverage # runs the tests and enforces the coverage threshold
make dmg      # packages the app into a disk image
```

The app is ad-hoc signed, not notarized. On a Mac other than the one that built
it, open it the first time with right-click → Open (or allow it under System
Settings → Privacy & Security). After a rebuild, macOS may ask for permission
to use the saved Keychain item again.

## Building for iPad

The iPad app is built from `ios/PaizoLibraryManager.xcodeproj`, which uses the
same Swift package as the Mac app.

1. Open `ios/PaizoLibraryManager.xcodeproj` in Xcode.
2. Select the PaizoLibraryManager-iPad target, open Signing & Capabilities and choose
   your team. A free Apple ID works; an app signed that way runs for seven days
   before it has to be installed again, a paid developer account for a year.
3. If Xcode says the bundle identifier is taken, change it to one of your own.
4. Connect the iPad, pick it as the run destination and press Run. The first
   time, the iPad asks you to trust the developer under Settings › General ›
   VPN & Device Management.

`make ipad-simulator` builds the app and starts it in an iPad simulator.

On the iPad, downloads appear in the Files app under On My iPad. Opening a file
shows a preview; the share button offers every app that accepts the file. The
Files app's tags cannot be set by an app, so tags stay inside the app. The Mac
and the iPad each keep their own catalog, tags and downloads.

## Installing a release

Download the disk image from the
[releases page](https://github.com/scooper4711/paizo-library-manager/releases),
open it and drag the app to Applications. A disk image is built and attached
automatically for every version tag.

## Where things are stored

| What | Where |
|---|---|
| Catalog, summaries, tags | `~/Library/Application Support/Paizo Library Manager/` (inside the app's container on the iPad) |
| Cover artwork | `~/Library/Application Support/Paizo Library Manager/Covers/` |
| Downloaded files | Mac: `~/Library/Application Support/Paizo Library Manager/Files/` (changeable in Settings). iPad: the app's Documents folder, shown in Files |
| Password | macOS Keychain, service `store.paizo.com` |

## Documentation

The requirements and design are in [`docs/specs/library-manager`](docs/specs/library-manager).
