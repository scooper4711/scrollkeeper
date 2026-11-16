#if os(iOS)
import ScrollkeeperKit
import SwiftUI

/// Takes the `scrollkeeper://` links other Tableside Toolkit apps open on the iPad (app-handoff 2.9). A download
/// or open request shows the title and downloads it when needed. Nothing is sent back: the requesting app finds
/// the title in the shared library when the user returns to it. A link that names no request, such as a bare
/// `scrollkeeper://`, and an index request only bring the app forward.
struct PadHandoffHandler: ViewModifier {
    @Environment(LibraryStore.self) private var store
    @Binding var selection: LibraryTitle.ID?
    @State private var failure: HandoffError?

    func body(content: Content) -> some View {
        content
            // The window already open takes the link, rather than a new one opening for it.
            .handlesExternalEvents(preferring: [HandoffRequest.scheme], allowing: [HandoffRequest.scheme])
            .onOpenURL { url in Task { await handle(url) } }
            .alert(isPresented: isShowingFailure, error: failure) {
                Button("OK") { failure = nil }
            }
    }

    private func handle(_ url: URL) async {
        let request: HandoffRequest
        do {
            request = try HandoffRequest(url: url)
        } catch .unrecognizedLink {
            return
        } catch {
            failure = error
            return
        }
        guard request.action != .index else { return }
        selection = request.sku
        do {
            _ = try await store.handoffFiles(for: request)
        } catch {
            failure = error
        }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }
}
#endif
