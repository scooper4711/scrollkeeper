import SwiftUI

#if os(macOS)
import AppKit
#else
import QuickLook
import UIKit
#endif

/// Opening downloaded files: with applications on the Mac, with a preview and the share sheet on the iPad.
@MainActor
enum FileOpener {
    /// Shows the file or folder in the Finder, or in the Files app.
    static func reveal(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #else
        // The Files app opens a folder given with its own URL scheme.
        let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        if let files = URL(string: "shareddocuments://" + folder.path(percentEncoded: true)) {
            UIApplication.shared.open(files)
        }
        #endif
    }

    #if os(macOS)
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func open(_ url: URL, with application: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Every application registered for the file's type, by name.
    static func applications(for url: URL) -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: url).sorted {
            name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending
        }
    }

    static func name(of application: URL) -> String {
        FileManager.default.displayName(atPath: application.path).replacingOccurrences(of: ".app", with: "")
    }
    #endif
}

/// "Open" plus a way to hand the file to another application.
struct OpenControls: View {
    let url: URL
    #if !os(macOS)
    @State private var preview: URL?
    #endif

    var body: some View {
        HStack(spacing: 6) {
            #if os(macOS)
            Button("Open") { FileOpener.open(url) }
            Menu("Open With") { applicationButtons }
                .fixedSize()
            #else
            Button("Open") { preview = url }
                .quickLookPreview($preview)
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            #endif
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        // Buttons keep their size; text beside them gives way instead.
        .fixedSize()
    }

    #if os(macOS)
    @ViewBuilder private var applicationButtons: some View {
        let applications = FileOpener.applications(for: url)
        ForEach(applications, id: \.self) { application in
            Button {
                FileOpener.open(url, with: application)
            } label: {
                Label {
                    Text(FileOpener.name(of: application))
                } icon: {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
                }
            }
        }
        if applications.isEmpty {
            Text("No application can open this file")
        }
    }
    #endif
}
