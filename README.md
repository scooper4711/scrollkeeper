# Paizo Library Manager

A native macOS app for browsing and downloading the digital library attached to
your [paizo.com](https://store.paizo.com) account.

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
  lite versions) into one title, and lets you download the single file, the
  zip of all chapters, or individual chapters.
- Three ways to browse: cover thumbnails, a list, and a sortable column view.
- Search, plus filtering by game system, product type, level, format and tag.
- Automatic classification: adventure paths, stand-alone adventures, society
  scenarios (with season or year), maps, rulebooks, fiction and more.
- Tags that are written to the downloaded files as Finder tags.
- Downloaded files are kept on disk and can be opened straight from the app.

## Requirements

- macOS 14 or later
- Xcode 16 or later (Swift 6 toolchain) to build

## Building

```sh
make app      # builds build/Paizo Library Manager.app
make run      # builds and launches the app
make test     # runs the unit tests
make lint     # runs SwiftLint
make coverage # runs the tests and enforces the coverage threshold
```

The app is ad-hoc signed. The first time it reads its saved password after a
rebuild, macOS may ask for permission to use the Keychain item.

## Where things are stored

| What | Where |
|---|---|
| Catalog, summaries, tags | `~/Library/Application Support/Paizo Library Manager/` |
| Cover artwork | `~/Library/Application Support/Paizo Library Manager/Covers/` |
| Downloaded files | `~/Library/Application Support/Paizo Library Manager/Files/` (changeable in Settings) |
| Password | macOS Keychain, service `store.paizo.com` |

## Documentation

The requirements and design are in [`docs/specs/library-manager`](docs/specs/library-manager).
