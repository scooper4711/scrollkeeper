#if os(macOS)
import AppKit
import Observation
import ScrollkeeperKit
import SwiftUI

/// Answers `scrollkeeper://` links from other Tableside Toolkit apps. An open request shows the
/// title, downloads it when needed and opens its files in the app that asked; a download request
/// only downloads, in the background; an index request hands the app the list of titles it can open.
///
/// The app delegate passes it the links, so a request is answered whether or not the library window
/// is open, including the one that launched the app.
@MainActor
@Observable
final class HandoffCoordinator {
    /// The title an open request asked for, until the library window selects it.
    var requestedSelection: LibraryTitle.ID?
    /// Why the last request failed, for the library window to show.
    var failure: HandoffError?
    @ObservationIgnored private let store: LibraryStore

    init(store: LibraryStore) {
        self.store = store
    }

    func handle(_ url: URL) {
        Task { await handleLink(url) }
    }

    private func handleLink(_ url: URL) async {
        let request: HandoffRequest
        do {
            request = try HandoffRequest(url: url)
        } catch {
            failure = error
            return
        }
        do {
            try await handle(request)
        } catch {
            failure = error
            send(.failed(error.localizedDescription), for: request)
        }
    }

    private func handle(_ request: HandoffRequest) async throws(HandoffError) {
        if request.action == .index {
            try await open([store.handoffIndex(for: request.app)], in: request.app)
            return
        }
        if request.action == .open {
            requestedSelection = request.sku
        }
        let reporter = reportProgress(of: request)
        defer { reporter.cancel() }
        let files = try await store.handoffFiles(for: request)
        reporter.cancel()
        send(.done, for: request)
        if request.action == .open {
            try await open(files, in: request.app)
        }
    }

    /// Tells an app that shows the progress itself how the download goes, while the request waits for it.
    private func reportProgress(of request: HandoffRequest) -> Task<Void, Never> {
        Task {
            var throttle = HandoffStatusThrottle()
            while !Task.isCancelled {
                if let status = store.handoffStatus(for: request), throttle.shouldSend(status) {
                    send(status, for: request)
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// Sends the status as a link in the app's scheme, without bringing the app forward.
    private func send(_ status: HandoffStatus, for request: HandoffRequest) {
        guard let url = status.url(for: request.app, sku: request.sku) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration)
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

/// Shows the library window's part in requests: it selects the title an open request names and shows
/// why a request failed.
struct HandoffHandler: ViewModifier {
    @Environment(HandoffCoordinator.self) private var handoff
    @Binding var selection: LibraryTitle.ID?

    func body(content: Content) -> some View {
        content
            .onChange(of: handoff.requestedSelection, initial: true) { _, requested in
                guard let requested else { return }
                selection = requested
                handoff.requestedSelection = nil
            }
            .alert(isPresented: isShowingFailure, error: handoff.failure) {
                Button("OK") { handoff.failure = nil }
            }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding(get: { handoff.failure != nil }, set: { if !$0 { handoff.failure = nil } })
    }
}
#endif
