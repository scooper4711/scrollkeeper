import ScrollkeeperKit
import SwiftUI

/// Toolbar button for the list of downloads that are running, waiting or have failed.
///
/// The number of pending downloads is part of the button's own label. It must not be drawn as
/// an overlay: on iPadOS 26 a toolbar button with an overlay no longer receives its taps.
struct DownloadsButton: View {
    @Environment(LibraryStore.self) private var store
    @State private var isShowingList = false

    var body: some View {
        let pending = store.pendingDownloadCount
        Button {
            isShowingList.toggle()
        } label: {
            if pending > 0 {
                Label {
                    // The toolbar takes the button's spoken name from this text, not from the button.
                    Text("\(pending)")
                        .monospacedDigit()
                        .accessibilityLabel("Downloads, \(pending) in progress")
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                }
                .labelStyle(.titleAndIcon)
            } else {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
        }
        .accessibilityLabel(pending > 0 ? "Downloads, \(pending) in progress" : "Downloads")
        .accessibilityIdentifier("downloads-button")
        .help("Show downloads in progress")
        .popover(isPresented: $isShowingList, arrowEdge: .bottom) {
            DownloadsList()
                .frame(width: 380)
                .frame(minHeight: 120, maxHeight: 420)
        }
    }
}

/// The downloads list: each with its progress and buttons to cancel, retry or dismiss it.
struct DownloadsList: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.headline)
                Spacer()
                Button("Cancel All") { store.cancelAllDownloads() }
                    .controlSize(.small)
                    .disabled(store.pendingDownloadCount == 0)
            }
            .padding(12)
            Divider()
            if store.downloadJobs.isEmpty {
                Text("Nothing is downloading.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.downloadJobs) { job in
                            DownloadJobRow(job: job)
                            Divider()
                        }
                    }
                }
            }
            Text("Up to \(LibraryStore.maximumConcurrentDownloads) files download at a time; the rest wait.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }
}

private struct DownloadJobRow: View {
    @Environment(LibraryStore.self) private var store
    let job: DownloadJob

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name)
                    .font(.callout)
                    .lineLimit(2)
                status
            }
            Spacer()
            if !job.state.isPending {
                Button(job.state == .interrupted ? "Resume" : "Retry") { store.retryDownload(job.target) }
                    .controlSize(.small)
                    .help("Try this download again")
            }
            Button {
                job.state.isPending ? store.cancelDownload(job.target) : store.dismissDownload(job.target)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(job.state.isPending ? "Cancel this download" : "Remove from the list")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var status: some View {
        switch job.state {
        case let .inProgress(fraction):
            ProgressView(value: fraction)
        case .waiting:
            Text("Waiting")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .interrupted:
            Text("Interrupted. It resumes when you come back to Scrollkeeper or the connection returns.")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case let .failed(message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
