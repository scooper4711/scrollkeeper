import ScrollkeeperKit
import SwiftUI

/// The library as a grid of cover thumbnails.
struct CoverGridView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var selection: LibraryTitle.ID?

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 190), spacing: 18, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(store.visibleItems) { item in
                    CoverCell(item: item, isSelected: selection == item.id)
                        .onTapGesture { selection = item.id }
                }
            }
            .padding(18)
        }
    }
}

private struct CoverCell: View {
    @Environment(LibraryStore.self) private var store
    let item: LibraryTitle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            CoverImage(item: item)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) { downloadedBadge }
            Text(item.title)
                .font(.callout)
                .lineLimit(3)
                .multilineTextAlignment(.center)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .help(item.title)
    }

    @ViewBuilder private var downloadedBadge: some View {
        if store.outdatedItemIDs.contains(item.id) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .orange)
                .padding(4)
                .help("Downloaded; Paizo has a newer version")
        } else if store.downloadedItemIDs.contains(item.id) {
            Image(systemName: "arrow.down.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .padding(4)
                .help("Downloaded")
        }
    }
}

extension LibraryTitle {
    /// Type and series in one line, for cells and rows.
    var subtitle: String {
        let parts = [classification.productLine.label, classification.series, classification.part]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
