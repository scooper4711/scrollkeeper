import PaizoLibraryKit
import SwiftUI

/// Toolbar menu with the filters that apply on top of the sidebar scope.
struct FilterMenu: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Game", selection: $store.query.gameSystem) {
                Text("Any Game").tag(GameSystem?.none)
                ForEach(GameSystem.allCases) { Text($0.label).tag(GameSystem?.some($0)) }
            }
            Picker("Type", selection: $store.query.productLine) {
                Text("Any Type").tag(ProductLine?.none)
                ForEach(ProductLine.allCases) { Text($0.label).tag(ProductLine?.some($0)) }
            }
            Picker("Format", selection: $store.query.format) {
                Text("Any Format").tag("")
                ForEach(store.facets.formats, id: \.self) { Text($0).tag($0) }
            }
            Picker("Level", selection: $store.query.level) {
                Text("Any Level").tag(Int?.none)
                ForEach(1...20, id: \.self) { Text("Level \($0)").tag(Int?.some($0)) }
            }
            Toggle("Downloaded Only", isOn: $store.query.downloadedOnly)
            Divider()
            Button("Clear Filters") { store.query.clearFilters() }
                .disabled(!store.query.hasFilters)
        } label: {
            Label("Filter", systemImage: store.query.hasFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .help("Filter by game, type, format, level or download state")
    }
}
