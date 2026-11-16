#if os(iOS)
import SwiftUI

/// Replaces the About item in the iPad's menu bar, whose default opens an empty window, with one that opens
/// `AboutWindow`.
struct PadAboutCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) { AboutWindowButton() }
    }
}

/// The notice, links and acknowledgments that Settings shows, in a window of their own. It takes no links, which
/// still reach the library window.
struct AboutWindow: Scene {
    static let id = "about"

    var body: some Scene {
        WindowGroup("About \(AboutInfo.appName)", id: Self.id) {
            AboutWindowContent()
        }
        .handlesExternalEvents(matching: [])
    }
}

/// Opens the About window; a view of its own, since `openWindow` is read from a view's environment.
private struct AboutWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About \(AboutInfo.appName)") { openWindow(id: AboutWindow.id) }
    }
}

private struct AboutWindowContent: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        NavigationStack {
            Form {
                AboutView()
                AcknowledgmentsView()
            }
            .navigationTitle("About \(AboutInfo.appName)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismissWindow(id: AboutWindow.id) }
                }
            }
        }
    }
}
#endif
