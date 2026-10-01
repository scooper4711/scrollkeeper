import AppKit
import PaizoLibraryKit
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
            if !files.isEmpty {
                Button("Show in Finder") { FileOpener.reveal(target.localURL) }
                    .controlSize(.small)
            }
            Button("Save As…", action: saveElsewhere)
                .controlSize(.small)
        } else if files.isEmpty {
            Button("Download") { store.download(target) }
                .controlSize(.small)
        } else {
            if !target.isArchive {
                OpenControls(url: target.localURL)
            }
            downloadedMenu(target: target)
        }
    }

    private func downloadedMenu(target: DownloadTarget) -> some View {
        Menu {
            Button("Show in Finder") { FileOpener.reveal(target.localURL) }
            Button("Download Again") { store.download(target) }
            Divider()
            Button("Delete Download", role: .destructive) { store.deleteDownload(target) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("More actions for this download")
    }

    /// Asks where to put the zip and downloads it there; the library keeps no copy.
    private func saveElsewhere() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = store.locator.suggestedFileName(for: edition, in: item)
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let destination = panel.url {
            exported = store.export(edition, of: item, to: destination)
        }
    }

    private var formatDescription: String {
        let type = edition.entitlement.fileExtension.uppercased()
        if edition.isSavedElsewhere {
            return "ZIP, saved where you choose"
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
