# Scrollkeeper — Requirements

Scrollkeeper is an unofficial library manager for a customer's Paizo purchases.
The name deliberately contains no Paizo trademark; Paizo is named only to say
what the app works with.

## Purpose

Paizo's web library (`https://store.paizo.com/library/`) takes about fifteen
seconds to load each page of fifty items and searching is just as slow. A
customer with a few thousand titles cannot browse it comfortably. Scrollkeeper keeps a local copy of the customer's catalog and offers fast browsing,
searching, classification, tagging and downloading in a native macOS app.

## Glossary

- **Entitlement**: one downloadable package the account owns, as listed by the
  Paizo library (for example "Pathfinder NPC Core PDF - File per Chapter").
- **Title**: one product. A title groups all entitlements that come from the
  same product SKU.
- **Edition**: one entitlement shown inside its title (single file, file per
  chapter, lite single file, ePub, and so on).
- **Archive**: an edition that Paizo delivers as a zip file, such as a
  file-per-chapter edition or a set of map images.
- **Sync**: fetching the list of entitlements from Paizo.

## 1. Credentials

1.1 The app has a Settings window where the user enters their Paizo account
    email and password.
1.2 The password is stored in the macOS Keychain, never in a plain file or in
    user defaults.
1.3 The email and password fields are marked as username and password fields so
    that Password AutoFill from the Passwords app can fill them.
1.4 Settings offers a "Sign In" action that verifies the credentials against
    Paizo and reports success or the reason for failure.
1.5 The user can remove the stored credentials.

## 2. Catalog sync

2.1 When valid credentials exist and the library has never been fetched to the
    end, the app starts a full sync automatically. This also restarts a first
    sync that was interrupted.
2.2 A full sync downloads every entitlement of the account.
2.3 While a sync runs, the app shows a progress bar with the number of
    entitlements fetched and the total.
2.4 Titles appear in the window as soon as their page has been fetched; the
    user does not have to wait for the sync to finish.
2.5 The catalog is stored on disk and loaded at the next launch without
    contacting Paizo.
2.6 The user can ask for a refresh. A refresh fetches only the newest
    entitlements and stops when it reaches ones that are already known.
2.7 The user can ask for a full resync.
2.8 The user can cancel a running sync. What was already fetched is kept.
2.9 A failed page is retried; if it still fails, the sync reports the error and
    keeps what was fetched.

## 3. Artwork and summaries

3.1 For each title the app fetches a cover image and a summary from the public
    Paizo storefront, which needs no sign-in.
3.2 This runs concurrently with the catalog sync and has its own progress
    indication.
3.3 Other metadata the storefront offers is kept as well: game edition (brand),
    category path, page count, starting level, author and the link to the store
    page. The author is the storefront's author field when there is one, and
    otherwise the credit in the summary ("Written by …", or a "by …" line).
3.3a Metadata stored by a version of the app that kept fewer fields is fetched
    again; cover artwork is not downloaded again.
3.4 Artwork and metadata are cached on disk and not fetched again for titles
    that already have them.
3.5 A title that the storefront does not know is still shown. Its cover is the
    product image Paizo lists with the entitlement when there is one, and a
    placeholder otherwise.

## 4. Grouping

4.1 Entitlements that come from the same product SKU are shown as one title.
4.2 Each edition is labelled by its kind: Single File, File per Chapter, Lite
    Single File, Lite File per Chapter, ePub, or the distinguishing part of its
    name.
4.3 An entitlement without a usable SKU is shown as its own title.

## 5. Downloading

5.1 The user can download any edition of a title.
5.2 For documents a zip file is only the means of delivery. When an edition
    arrives as a zip (a file-per-chapter edition, a single-file edition
    bundled with its maps, a scenario with handouts), the app downloads the
    zip, unpacks it into a folder for that edition, removes the zip and keeps
    the unpacked files. The individual files are then listed under the edition.
5.2a A zip of material that is not for reading in the app is not kept by the
    app: community use packages, image sets (JPG, PNG), logos, icons and
    audio. Downloading one asks where to save the zip and saves it there.
5.3 Downloads show progress and can run several at a time.
5.4 A downloaded file is kept on disk. Its location is a folder inside the
    user's Library directory by default and can be changed in Settings.
5.5 Once a file is downloaded, the app offers "Open", "Open With" and "Show in
    Finder" instead of "Download". "Open With" lists every application that
    has registered itself for the file's type.
5.6 The user can delete a downloaded file from within the app.
5.7 An entitlement that has no file attached on Paizo's side is shown as
    unavailable.

## 6. Browsing

6.1 The app offers three views of the catalog: cover thumbnails, a list, and a
    column view (table).
6.2 The column view can be sorted by clicking a column header. The chosen sort
    order also applies to the other two views.
6.3 A search field filters titles as the user types. It matches the title, SKU,
    edition names, series, author, summary and tags. All words must match.
6.4 Titles can be filtered by game system, product type, format, level and tag,
    and by download state: downloaded, or not downloaded. A title counts as
    downloaded when at least one of its files is on disk. "Not downloaded"
    combined with a category shows what in that category is still missing.
6.4a When the search and filters match nothing and a filter is set, the empty
    view offers to clear the filters and the filter button pulses briefly.
6.5 Selecting a title shows its details: cover, summary, metadata, editions
    with their download actions, and tags.

## 7. Classification

7.1 Each title is classified automatically by game system: Pathfinder First
    Edition, Pathfinder Second Edition, Starfinder First Edition, Starfinder
    Second Edition, Adventure Card Game, or other.
7.2 Each title is classified by product type: adventure path, adventure,
    society scenario, quest, bounty, one-shot, rulebook, setting, player
    companion, maps, pawns, cards, fiction, community use, or other.
7.3 Adventure path volumes record the campaign name, the volume number and the
    part within the campaign.
7.4 Society scenarios record their season (or year) and scenario number.
7.5 The level range an adventure is written for is recorded: from the
    storefront's starting level when it gives one, otherwise from the title or
    summary.
7.6 The file formats of a title (PDF, ZIP, ePub) are recorded.

## 8. Tags

8.1 The user can add and remove tags on a title.
8.2 Tags are stored with the catalog and survive a resync.
8.3 Tags are written to the title's downloaded files as Finder tags, both when
    a tag changes and when a file finishes downloading.
8.4 Finder tags added to a downloaded file outside the app are picked up as
    tags on the title when the app loads the catalog.

## 9. Quality

9.1 All logic outside SwiftUI view declarations lives in a library target with
    unit tests; line and region coverage of that target is at least 80%.
9.2 No account data, tokens or credentials are written to logs or committed to
    the repository.
9.3 The app does not change anything on the Paizo account.

## 10. iPad

10.1 The app also runs on iPad (iPadOS 17 or later) with the same catalog
     sync, artwork, grouping, classification, search, filters, three views,
     detail pane and tags as on the Mac.
10.2 The account is kept in the iPad's Keychain and the sign-in fields support
     Password AutoFill.
10.3 Downloaded files are kept in the app's Documents folder, so they also
     appear in the Files app under "On My iPad".
10.4 "Open" shows a downloaded file in a preview inside the app. "Share" hands
     it to the share sheet, which lists every app that accepts the file; this
     takes the place of "Open With" on the Mac.
10.5 A zip that the app does not keep (5.2a) is downloaded and then handed to
     the share sheet, from where it can be saved to Files or sent to another
     app.
10.6 Tags are kept in the app. iPadOS does not let an app set the Files app's
     tags on a file, so 8.3 and 8.4 apply to the Mac only.
10.7 Settings are reached from a button in the toolbar.
10.8 The Mac and the iPad each sync with Paizo on their own; catalog, tags and
     downloads are not shared between devices.

## 11. Paizo's Community Use Policy

11.1 The app is free. No feature depends on a payment.
11.2 The notice that Paizo's Community Use Policy prescribes is shown, in the
     policy's own wording, in the README, in the Mac app's About panel, and in
     the settings of both apps.
11.3 The Mac app and the README link to a page for optional donations. The
     iPad app does not, because Apple restricts links to outside payment pages.
11.4 Cover images and product descriptions are shown unmodified. The app icon
     and other artwork of the app itself use no Paizo material.
11.5 The licence notices of included third-party software are part of the app
     (Settings › About) and of the repository (`THIRD-PARTY-NOTICES.md`).
11.6 Paizo's terms forbid removing copyright, trademark or other proprietary
     notices from its content. Product descriptions are therefore fetched and
     shown complete and unaltered, never shortened, since some end in such
     notices. Covers are shown whole, without cropping or rounded corners.
     Each description is followed by a credit to Paizo as its owner.
     Downloaded files are saved exactly as Paizo delivers them.
