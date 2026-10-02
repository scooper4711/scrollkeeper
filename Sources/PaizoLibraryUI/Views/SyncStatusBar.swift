import PaizoLibraryKit
import SwiftUI

/// Progress of the catalog sync and the artwork fetch, shown along the bottom of the window.
struct SyncStatusBar: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        if store.sync.isRunning || store.artwork.isRunning || !store.sync.failure.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if store.sync.isRunning {
                    catalogProgress
                }
                if store.artwork.isRunning {
                    artworkProgress
                }
                if !store.sync.failure.isEmpty, !store.sync.isRunning {
                    Label(store.sync.failure, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private var catalogProgress: some View {
        HStack(spacing: 10) {
            if store.sync.total > 0 {
                ProgressView(value: store.sync.fraction)
                    .frame(maxWidth: 260)
                Text("Loading library: \(store.sync.fetched) of \(store.sync.total) downloads listed")
            } else {
                ProgressView()
                    .controlSize(.small)
                Text("Signing in and asking Paizo for your library…")
            }
            Spacer()
            Button("Stop") { store.cancelSync() }
                .controlSize(.small)
        }
        .font(.callout)
    }

    private var artworkProgress: some View {
        HStack(spacing: 10) {
            ProgressView(value: store.artwork.fraction)
                .frame(maxWidth: 260)
            Text("Artwork and summaries: \(store.artwork.done) of \(store.artwork.total) titles")
            Spacer()
        }
        .font(.callout)
    }
}
