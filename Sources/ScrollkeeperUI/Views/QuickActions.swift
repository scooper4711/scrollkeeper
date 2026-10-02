import ScrollkeeperKit
import SwiftUI

#if !os(macOS)
import QuickLook
#endif

/// What the iPad previews when a title is opened: the tapped file and the others it came with.
struct PreviewRequest {
    var current: URL?
    var files: [URL] = []
}

@MainActor
enum QuickOpen {
    /// Opens a download: with the default application on the Mac, as a preview on the iPad.
    static func open(_ target: DownloadTarget, in store: LibraryStore, preview: inout PreviewRequest) {
        #if os(macOS)
        FileOpener.open(store.openableURL(for: target))
        #else
        let files = store.files(in: target)
        preview = PreviewRequest(current: files.first, files: files)
        #endif
    }
}

extension View {
    /// Shows the iPad preview that `QuickOpen` asks for. Does nothing on the Mac.
    @ViewBuilder
    func quickPreview(_ request: Binding<PreviewRequest>) -> some View {
        #if os(macOS)
        self
        #else
        quickLookPreview(request.current, in: request.wrappedValue.files)
        #endif
    }
}

/// Download, Update and Open as menu items, for the right-click menu of a title.
struct QuickActionMenuItems: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    let open: (DownloadTarget) -> Void

    var body: some View {
        let actions = store.quickActions(for: item)
        if let target = actions.open {
            Button("Open") { open(target) }
        }
        if let target = actions.download {
            if store.downloads[target.id]?.isPending == true {
                Button("Cancel Download") { store.cancelDownload(target) }
            } else {
                Button(actions.isUpdate ? "Update" : "Download") { store.download(target) }
            }
        }
        if actions == TitleActions() {
            Text("See the details for this title's downloads")
        }
    }
}

/// Adds the right-click menu of quick actions to a cell or row.
struct QuickActionMenu: ViewModifier {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    @State private var preview = PreviewRequest()

    func body(content: Content) -> some View {
        content
            .contextMenu {
                QuickActionMenuItems(item: item) { QuickOpen.open($0, in: store, preview: &preview) }
            }
            .quickPreview($preview)
    }
}

/// Download, Update and Open as round buttons, shown while the pointer is over a title.
struct QuickActionButtons: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    @State private var preview = PreviewRequest()

    var body: some View {
        let actions = store.quickActions(for: item)
        HStack(spacing: 10) {
            if let target = actions.download {
                downloadControl(target, isUpdate: actions.isUpdate)
            }
            if let target = actions.open {
                Button {
                    QuickOpen.open(target, in: store, preview: &preview)
                } label: {
                    Label("Open", systemImage: "book.circle.fill")
                }
                .foregroundStyle(.green)
                .help("Open")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.system(size: 26))
        .symbolRenderingMode(.hierarchical)
        .padding(.horizontal, actions == TitleActions() ? 0 : 10)
        .padding(.vertical, actions == TitleActions() ? 0 : 6)
        .background(.regularMaterial, in: Capsule())
        .quickPreview($preview)
    }

    @ViewBuilder
    private func downloadControl(_ target: DownloadTarget, isUpdate: Bool) -> some View {
        switch store.downloads[target.id] {
        case let .inProgress(fraction):
            ProgressView(value: fraction)
                .progressViewStyle(.circular)
                .controlSize(.small)
                .help("Downloading")
        case .waiting:
            Image(systemName: "clock")
                .help("Waiting for other downloads to finish")
        default:
            Button {
                store.download(target)
            } label: {
                Label(isUpdate ? "Update" : "Download",
                      systemImage: isUpdate ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.down.circle.fill")
            }
            .foregroundStyle(isUpdate ? Color.orange : Color.accentColor)
            .help(isUpdate ? "Download Paizo's newer version" : "Download \(target.remote.displayName)")
        }
    }
}
