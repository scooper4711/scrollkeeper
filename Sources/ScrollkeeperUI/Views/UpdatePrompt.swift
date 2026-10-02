#if os(macOS)
import AppKit
import ScrollkeeperKit
import SwiftUI

/// Tells the user what an update check found and asks before downloading anything.
/// While the check or the download runs, a line of progress shows above the window's status bar.
struct UpdatePrompt: ViewModifier {
    @Environment(AppUpdater.self) private var updater

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) { progress }
            .alert(updater.state.title, isPresented: isShowingResult) {
                buttons
            } message: {
                Text(updater.state.message)
            }
    }

    /// Closing the alert clears the result. Starting the download changes the state first, so the
    /// same closing leaves the download alone.
    private var isShowingResult: Binding<Bool> {
        Binding(get: { updater.state.isResult }, set: { if !$0 { updater.dismiss() } })
    }

    @ViewBuilder private var buttons: some View {
        switch updater.state {
        case .available:
            Button("Download") { updater.startDownload() }
                .keyboardShortcut(.defaultAction)
            Button("Not Now", role: .cancel) { updater.dismiss() }
        case let .downloaded(_, file):
            Button("Open Disk Image") {
                NSWorkspace.shared.open(file)
                updater.dismiss()
            }
            .keyboardShortcut(.defaultAction)
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([file])
                updater.dismiss()
            }
            Button("Later", role: .cancel) { updater.dismiss() }
        default:
            Button("OK") { updater.dismiss() }
        }
    }

    @ViewBuilder private var progress: some View {
        if updater.state.isBusy {
            HStack(spacing: 10) {
                if case let .downloading(_, fraction) = updater.state {
                    ProgressView(value: fraction)
                        .frame(maxWidth: 220)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(updater.state.title)
                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
#endif
