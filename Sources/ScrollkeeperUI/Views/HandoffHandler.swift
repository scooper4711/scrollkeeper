#if os(macOS)
import AppKit
import ScrollkeeperKit
import SwiftUI

/// Answers `scrollkeeper://open` links from other Tableside Toolkit apps: shows the title,
/// downloads it when needed and opens its files in the app that asked.
struct HandoffHandler: ViewModifier {
    @Environment(LibraryStore.self) private var store
    @Binding var selection: LibraryTitle.ID?
    @State private var failure: HandoffError?

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                Task { await handle(url) }
            }
            // Links reach the open library window instead of opening another.
            .handlesExternalEvents(preferring: [HandoffRequest.scheme], allowing: [HandoffRequest.scheme])
            .alert(isPresented: isShowingFailure, error: failure) {
                Button("OK") { failure = nil }
            }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    private func handle(_ url: URL) async {
        do {
            let request = try HandoffRequest(url: url)
            selection = request.sku
            let files = try await store.handoffFiles(for: request)
            try await open(files, in: request.app)
        } catch {
            failure = error
        }
    }

    private func open(_ files: [URL], in app: HandoffApp) async throws(HandoffError) {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            throw .appNotInstalled(app: app.name)
        }
        do {
            _ = try await workspace.open(files, withApplicationAt: appURL, configuration: .init())
        } catch {
            throw .appNotInstalled(app: app.name)
        }
    }
}
#endif
