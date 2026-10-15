# App Handoff — Requirements

Other Tableside Toolkit apps can ask Scrollkeeper for a title the user owns.
Scrollkeeper downloads it if needed and opens it in the app that asked. The
first such app is Mapsmith, which lets the user pick a map by name.

## Glossary

- **Requesting app**: a Tableside Toolkit app that asks Scrollkeeper to open a
  title, such as Mapsmith.
- **Map index**: a file Scrollkeeper writes that lists the map titles the user
  owns, for requesting apps to search.

## 1. Map index

1.1 Whenever the catalog changes, the Mac app writes the map index to
    `<data folder>/Shared/maps.json`, where the data folder is
    `~/Library/Application Support/Scrollkeeper`.
1.2 The index lists every title classified as Maps that has an edition that
    can be downloaded with one click. Titles that are only an image pack or
    have no file attached are left out.
1.3 Each entry gives the SKU, the title, the series and number when
    classification found them, and whether an up-to-date copy is on disk.
1.3a The index is rewritten when a download finishes or a copy becomes out of
    date, so a requesting app can show which titles still need downloading.
1.4 The index has a format version and the time it was written. A requesting
    app that does not know the version must not guess at its contents.
1.5 The index is rewritten only when its entries change.
1.6 The index holds titles and SKUs only: no account email, token or file
    location (9.2 of the library-manager requirements).

## 2. Open request

2.1 The Mac app handles URLs of the form
    `scrollkeeper://open?sku=<SKU>&app=<app key>`.
2.2 The app key must name a known requesting app. The only one today is
    `mapsmith`. Any other key is refused with an alert, so a link cannot make
    Scrollkeeper start an arbitrary application.
2.3 Scrollkeeper picks the edition the quick actions would pick (5.x): the
    single file first, a PDF over other formats, never an image pack.
2.4 When that edition is on disk and up to date, its files are opened at once.
    Otherwise it is downloaded first, through the normal download queue
    (5.3: at most five at a time), and opened when the download finishes.
2.5 Only files the requesting app can open are sent to it; for Mapsmith these
    are PDFs and images. When an archive unpacks to several, its PDFs are sent
    if it has any, otherwise all its images. Map packs repeat the PDF's pages
    as images at half the resolution (150 against 300 ppi), so the images add
    only duplicate windows.
2.6 While a download runs, Scrollkeeper shows the title, so its progress is
    visible.
2.7 When the request cannot be met, Scrollkeeper says why in an alert: the
    account is signed out, the title is not in the library, it has no edition
    to download, the download failed, the requesting app is not installed, or
    the download holds no file the requesting app can open.
2.8 One request handles one title (5.3b).
2.9 The iPad app does not handle open requests.
2.10 The Mac app also handles `scrollkeeper://download?sku=<SKU>&app=<app key>`:
    the same as an open request, except that nothing is opened and the
    library window's selection is left alone. The requesting app learns that
    the download finished from the map index (1.3a).
