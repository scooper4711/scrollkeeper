import PaizoLibraryKit
import SwiftUI

/// The library as sortable columns. The sort order chosen here also orders the other views.
struct TitleTableView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var selection: LibraryTitle.ID?

    private typealias Column = TableColumn<LibraryTitle, KeyPathComparator<LibraryTitle>, Text, Text>

    var body: some View {
        #if os(macOS)
        table
        #else
        // An iPad held upright is narrower than the columns need; the table keeps its width and
        // scrolls sideways instead of squeezing the title off the edge.
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                table.frame(width: max(Self.fullWidth, geometry.size.width), height: geometry.size.height)
            }
        }
        #endif
    }

    private static let fullWidth: CGFloat = 1180

    private var table: some View {
        @Bindable var store = store
        // A table takes at most ten columns directly, so they are given in two groups.
        return Table(store.visibleItems, selection: $selection, sortOrder: $store.sortOrder) {
            Group {
                Column("Title", value: \LibraryTitle.titleSortKey) { (item: LibraryTitle) in Text(item.title) }
                    .width(min: 220, ideal: 340)
                Column("Author", value: \LibraryTitle.author) { (item: LibraryTitle) in Text(item.author) }
                    .width(min: 80, ideal: 140)
                Column("Type", value: \LibraryTitle.productLineLabel) { (item: LibraryTitle) in
                    Text(item.productLineLabel)
                }
                .width(min: 80, ideal: 120)
                Column("Game", value: \LibraryTitle.gameSystemLabel) { (item: LibraryTitle) in
                    Text(item.gameSystemLabel)
                }
                .width(min: 80, ideal: 105)
                Column("Series", value: \LibraryTitle.series) { (item: LibraryTitle) in Text(item.series) }
                    .width(min: 70, ideal: 140)
            }
            Group {
                Column("No.", value: \LibraryTitle.numberSortKey) { (item: LibraryTitle) in
                    Text(item.classification.number.map(String.init) ?? "").monospacedDigit()
                }
                .width(40)
                Column("Level", value: \LibraryTitle.levelSortKey) { (item: LibraryTitle) in
                    Text(item.classification.levelLabel).monospacedDigit()
                }
                .width(48)
                Column("Pages", value: \LibraryTitle.pageCount) { (item: LibraryTitle) in
                    Text(item.pageCount > 0 ? String(item.pageCount) : "").monospacedDigit()
                }
                .width(48)
                Column("Formats", value: \LibraryTitle.formatsLabel) { (item: LibraryTitle) in
                    Text(item.formatsLabel)
                }
                .width(min: 50, ideal: 70)
                Column("Added", value: \LibraryTitle.dateAdded) { (item: LibraryTitle) in
                    Text(Self.addedLabel(item)).monospacedDigit()
                }
                .width(min: 70, ideal: 86)
                Column("Tags", value: \LibraryTitle.tagsLabel) { (item: LibraryTitle) in Text(item.tagsLabel) }
                    .width(min: 60, ideal: 110)
            }
        }
    }

    private static func addedLabel(_ item: LibraryTitle) -> String {
        item.dateAdded == .distantPast ? "" : item.dateAdded.formatted(date: .numeric, time: .omitted)
    }
}
