import AppKit
import SwiftUI

/// Opening files with the default application or any other that can handle them.
@MainActor
enum FileOpener {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func open(_ url: URL, with application: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
}

/// "Open" plus a menu of the other applications that can open the file.
struct OpenControls: View {
    let url: URL

    var body: some View {
        HStack(spacing: 6) {
            Button("Open") { FileOpener.open(url) }
            Menu("Open With") {
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
            .fixedSize()
        }
        .controlSize(.small)
    }
}
