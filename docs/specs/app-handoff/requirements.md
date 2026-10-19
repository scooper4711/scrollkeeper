# App Handoff — Requirements

Other Tableside Toolkit apps can ask Scrollkeeper for a title the user owns.
Scrollkeeper downloads it if needed and opens it in the app that asked. The
first such app is Mapsmith, which lets the user pick a map by name; Pluck
does the same for any title with a PDF.

## Glossary

- **Requesting app**: a Tableside Toolkit app that asks Scrollkeeper to open a
  title, such as Mapsmith.
- **Map index**: a file Scrollkeeper writes that lists the map titles the user
  owns, for requesting apps to search.
- **Title index**: a file Scrollkeeper writes when a requesting app asks for
  it, listing the titles that app can open, and hands to the app.

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
2.2 The app key must name a known requesting app: `mapsmith` or `pluck`. Any other key is refused with an alert, so a link cannot make
    Scrollkeeper start an arbitrary application.
2.3 Scrollkeeper picks the edition the quick actions would pick (5.x): the
    single file first, a PDF over other formats, never an image pack.
2.4 When that edition is on disk and up to date, its files are opened at once.
    Otherwise it is downloaded first, through the normal download queue
    (5.3: at most five at a time), and opened when the download finishes.
2.5 Only files the requesting app can open are sent to it; for Mapsmith these
    are PDFs and images, and for Pluck PDFs. When an archive unpacks to several, its PDFs are sent
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
    the download finished from a status link (4.2), or, for Mapsmith 1.1 and
    earlier, from the map index (1.3a).

## 3. Title index request

3.1 The Mac app handles `scrollkeeper://index?app=<app key>`. It names no
    title.
3.2 Scrollkeeper waits until its catalog is read, then writes the title index
    for that app to `<data folder>/Shared/<app key>.scrollkeeperindex` and
    opens it with the app. Being opened with the file gives a sandboxed app
    access to it, which reading Scrollkeeper's folder would not (1.1).
3.3 The index lists every title with an edition that can be downloaded with
    one click and that the app can open: a file of a type it accepts, or a zip
    of documents, which may hold some. Mapsmith's index lists only maps; Pluck's
    lists every such title. Each entry gives the SKU, the title,
    the product type, the series and number when classification found them,
    and whether an up-to-date copy is on disk.
3.4 Like the map index, it has a format version and the time it was written,
    and holds titles and SKUs only (1.4, 1.6).
3.5 The file has its own type, `io.github.scooper4711.scrollkeeper.index`
    (extension `scrollkeeperindex`, conforming to JSON), which Scrollkeeper
    declares and requesting apps import, so Launch Services can open it with
    them.
3.6 Before a catalog exists the request is refused with an alert that says to
    sign in.

## 4. Status for the requesting app

4.1 A requesting app may show how its request is going itself, so the user
    need not look at Scrollkeeper. Pluck and Mapsmith both do.
4.2 For such an app, Scrollkeeper opens links in the app's own scheme, in the
    background: `<scheme>://handoff?sku=<SKU>&state=downloading&fraction=<0…1>`
    while the title downloads (at most once per whole percent), `state=done`
    just before the files are opened, and `state=failed&reason=<text>` when
    the request cannot be met, with the text of the alert (2.7, 3.6). A failed
    index request has an empty SKU.

## 5. Shared download folder (planned)

Planned for when Scrollkeeper runs in the App Sandbox, which needs the
Developer ID (scrollkeeper#22, #23). Mac only; the iPad app keeps its
downloads in its Documents folder (10.3 of the library-manager requirements).

5.1 Scrollkeeper's default download folder is in a folder shared by the
    Tableside Toolkit apps, so that an app that imports many titles at once,
    such as Pawn Shop, Field Guide or Turnkeeper, can read the downloads
    without the user pointing it at them.
5.2 The first time it runs in the sandbox, Scrollkeeper moves the downloads in
    its old default folder into the shared folder. Nothing is downloaded
    again, and the move takes no longer than renaming a folder.
5.3 A download folder the user chose stays where it is. Other apps then ask
    the user for it, as they do today.
5.4 Only Scrollkeeper writes to the shared folder; other apps only read it,
    with the same layout as the download folder:
    `<title>/<edition name>.<ext>` and `<title>/<edition name>/`.
5.5 An app that reads the shared folder looks there first and asks the user
    for a folder only when it is missing or empty: when Scrollkeeper is not
    installed, has not yet run in the sandbox, or downloads to a folder the
    user chose.
5.6 Apps that open one title at a time, such as Mapsmith and Pluck, keep
    asking through the handoff (2, 3), which also downloads what is missing.
