import QuickLook
import ScrollkeeperKit
import SwiftUI

/// Space shows the selected title in Quick Look, as in Finder: its downloaded files, the book before its maps
/// and posters with arrows between them, or else its cover. Space again, or Escape, closes it.
struct SpacePreview: ViewModifier {
    @Environment(LibraryStore.self) private var store
    let selection: LibraryTitle.ID?
    @State private var preview = PreviewRequest()

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) { toggle() }
            .quickLookPreview($preview.current, in: preview.files)
    }

    private func toggle() -> KeyPress.Result {
        guard preview.current == nil else {
            preview = PreviewRequest()
            return .handled
        }
        guard let item = store.item(id: selection) else { return .ignored }
        let files = store.previewFiles(for: item)
        guard let first = files.first else { return .ignored }
        preview = PreviewRequest(current: first, files: files)
        return .handled
    }
}
