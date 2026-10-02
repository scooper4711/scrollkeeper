import ScrollkeeperKit
import SwiftUI

/// The library as a list with small covers.
struct TitleListView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var selection: LibraryTitle.ID?

    var body: some View {
        List(store.visibleItems, selection: $selection) { item in
            TitleRow(item: item)
        }
        #if os(macOS)
        .listStyle(.inset(alternatesRowBackgrounds: true))
        #else
        .listStyle(.plain)
        #endif
    }
}

private struct TitleRow: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(item: item)
                .frame(width: 42, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .lineLimit(1)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isHovered {
                QuickActionButtons(item: item)
            }
            if !item.tags.isEmpty {
                Text(item.tagsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(item.formatsLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: isOutdated ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(isOutdated ? .orange : .green)
                .opacity(store.downloadedItemIDs.contains(item.id) ? 1 : 0)
                .help(isOutdated ? "Downloaded; Paizo has a newer version" : "Downloaded")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .modifier(QuickActionMenu(item: item))
    }

    private var isOutdated: Bool { store.outdatedItemIDs.contains(item.id) }

    private var details: String {
        let level = item.classification.levelLabel.isEmpty ? "" : "Level \(item.classification.levelLabel)"
        let parts = [item.classification.gameSystem.label, item.subtitle, level]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
