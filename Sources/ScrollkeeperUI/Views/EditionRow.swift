import ScrollkeeperKit
import SwiftUI

/// One edition of a title with its download state and actions.
struct EditionRow: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    let edition: Edition
    /// Where a zip that is saved outside the library went, while this row is on screen.
    @State private var exported: DownloadTarget?

    var body: some View {
        let target = exported ?? store.locator.target(for: edition, in: item)
        let files = store.files(in: target)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(edition.label)
                        .fontWeight(.medium)
                    Text(formatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actions(target: target, files: files)
            }
            if store.isOutdated(target) {
                Label("Paizo updated this file after you downloaded it.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case let .failed(message) = store.downloads[target.id] {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if target.isArchive, !files.isEmpty {
                ArchiveFileList(files: files)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actions(target: DownloadTarget, files: [URL]) -> some View {
        if !edition.entitlement.hasFile {
            Text("Not available from Paizo")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if case let .inProgress(fraction) = store.downloads[target.id] {
            ProgressView(value: fraction)
                .frame(width: 90)
            Button("Cancel") { store.cancelDownload(target) }
                .controlSize(.small)
        } else if edition.isSavedElsewhere {
            savedElsewhereActions(target: target, isSaved: !files.isEmpty)
        } else if files.isEmpty {
            Button("Download") { store.download(target) }
                .controlSize(.small)
        } else {
            if store.isOutdated(target) {
                Button("Update") { store.download(target) }
                    .controlSize(.small)
                    .help("Download Paizo's newer version of this file")
            }
            if !target.isArchive {
                OpenControls(url: target.localURL)
            }
            downloadedMenu(target: target)
        }
    }

    /// A zip the app does not keep: on the Mac it is saved where the user says; on the iPad it
    /// is downloaded and then handed to the share sheet.
    @ViewBuilder
    private func savedElsewhereActions(target: DownloadTarget, isSaved: Bool) -> some View {
        #if os(macOS)
        if isSaved {
            Button(PlatformText.showInFileBrowser) { FileOpener.reveal(target.localURL) }
                .controlSize(.small)
        }
        Button("Save As…", action: saveElsewhere)
            .controlSize(.small)
        #else
        if isSaved {
            ShareLink(item: target.localURL) { Text("Share…") }
                .controlSize(.small)
        } else {
            Button("Download", action: downloadForSharing)
                .controlSize(.small)
        }
        #endif
    }

    private func downloadedMenu(target: DownloadTarget) -> some View {
        Menu {
            Button(PlatformText.showInFileBrowser) { FileOpener.reveal(target.localURL) }
            Button("Download Again") { store.download(target) }
            Divider()
            Button("Delete Download", role: .destructive) { store.deleteDownload(target) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .compactMenuStyle()
        .help("More actions for this download")
    }

    #if os(macOS)
    /// Asks where to put the zip and downloads it there; the library keeps no copy.
    private func saveElsewhere() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = store.locator.suggestedFileName(for: edition, in: item)
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let destination = panel.url {
            exported = store.export(edition, of: item, to: destination)
        }
    }
    #else
    /// Downloads the zip to a temporary place, from where the share sheet can pass it on.
    private func downloadForSharing() {
        let name = store.locator.suggestedFileName(for: edition, in: item)
        let destination = FileManager.default.temporaryDirectory.appending(path: "Shared/" + name)
        exported = store.export(edition, of: item, to: destination)
    }
    #endif

    private var formatDescription: String {
        guard let updated = edition.entitlement.dateUpdated else { return deliveryDescription }
        return deliveryDescription + " · Updated " + updated.formatted(date: .abbreviated, time: .omitted)
    }

    private var deliveryDescription: String {
        let type = edition.entitlement.fileExtension.uppercased()
        if edition.isSavedElsewhere {
            #if os(macOS)
            return "ZIP, saved where you choose"
            #else
            return "ZIP, passed on with the share sheet"
            #endif
        }
        guard edition.isUnpackedArchive else { return type }
        let count = edition.entitlement.assetCount
        return count > 1 ? "\(count) files, delivered as a ZIP and unpacked" : "Delivered as a ZIP and unpacked"
    }
}

/// The unpacked files of an archive, each with its own open controls.
private struct ArchiveFileList: View {
    let files: [URL]
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("\(files.count) files", isExpanded: $isExpanded) {
            ForEach(files, id: \.self) { file in
                HStack {
                    Text(file.deletingPathExtension().lastPathComponent)
                        .font(.callout)
                        .lineLimit(2)
                        .help(file.lastPathComponent)
                    Spacer()
                    OpenControls(url: file)
                }
                .padding(.vertical, 1)
            }
        }
        .font(.callout)
    }
}
