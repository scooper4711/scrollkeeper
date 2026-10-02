import PaizoLibraryKit
import SwiftUI

/// The library as sortable columns. The sort order chosen here also orders the other views.
struct TitleTableView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var selection: LibraryTitle.ID?

    var body: some View {
        @Bindable var store = store
        Table(store.visibleItems, selection: $selection, sortOrder: $store.sortOrder) {
            TableColumn("Title", value: \.titleSortKey) { item in
                Text(item.title)
                    .help(item.title)
            }
            .width(min: 220, ideal: 340)
            TableColumn("Type", value: \.productLineLabel)
                .width(min: 80, ideal: 120)
            TableColumn("Game", value: \.gameSystemLabel)
                .width(min: 80, ideal: 105)
            TableColumn("Series", value: \.series)
                .width(min: 70, ideal: 140)
            TableColumn("No.", value: \.numberSortKey) { item in
                Text(item.classification.number.map(String.init) ?? "")
                    .monospacedDigit()
            }
            .width(40)
            TableColumn("Level", value: \.levelSortKey) { item in
                Text(item.classification.levelLabel)
                    .monospacedDigit()
            }
            .width(48)
            TableColumn("Pages", value: \.pageCount) { item in
                Text(item.pageCount > 0 ? String(item.pageCount) : "")
                    .monospacedDigit()
            }
            .width(48)
            TableColumn("Formats", value: \.formatsLabel)
                .width(min: 50, ideal: 70)
            TableColumn("Added", value: \.dateAdded) { item in
                Text(item.dateAdded == .distantPast ? "" : item.dateAdded.formatted(date: .numeric, time: .omitted))
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 86)
            TableColumn("Tags", value: \.tagsLabel)
                .width(min: 60, ideal: 110)
        }
    }
}
